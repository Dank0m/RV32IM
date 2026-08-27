#!/usr/bin/env python3
"""Compile RISC-V C/ASM to IMEM program.hex and DMEM data.hex (Harvard)."""

import os
import struct
import subprocess
import sys
import tempfile

from elftools.elf.elffile import ELFFile
from elftools.elf.enums import ENUM_ST_INFO_TYPE
from elftools.elf.relocation import RelocationSection
from elftools.elf.sections import SymbolTableSection

CLANG = os.environ.get("CLANG", "clang")
TEXT_BASE = 0
DMEM_BASE = 0x10000
RESULT_RESERVE = 16
DATA_BASE = DMEM_BASE + RESULT_RESERVE
DMEM_SIZE_BYTES = 16384 * 4

R_RISCV_32 = 1
R_RISCV_BRANCH = 16
R_RISCV_JAL = 17
R_RISCV_CALL = 18
R_RISCV_CALL_PLT = 19
R_RISCV_PCREL_HI20 = 23
R_RISCV_PCREL_LO12_I = 24
R_RISCV_PCREL_LO12_S = 25
R_RISCV_HI20 = 26
R_RISCV_LO12_I = 27
R_RISCV_LO12_S = 28
R_RISCV_ADD32 = 35
R_RISCV_SUB32 = 39
R_RISCV_ALIGN = 43
R_RISCV_RELAX = 51
R_RISCV_SET32 = 56
R_RISCV_32_PCREL = 57

CFLAGS = [
    "-target", "riscv32",
    "-march=rv32im",
    "-mabi=ilp32",
    "-mno-relax",
    "-mcmodel=medlow",
    "-fno-pic",
    "-O2",
    "-ffreestanding",
    "-nostdlib",
    "-fno-builtin",
    "-I", os.path.join(os.path.dirname(os.path.abspath(__file__)), "port/include"),
]


def u32(x):
    return x & 0xFFFFFFFF


def sign_extend(val, bits):
    sign = 1 << (bits - 1)
    return (val & (sign - 1)) - (val & sign)


def patch_jal(instr, imm):
    if imm % 2:
        raise ValueError("JAL target not 2-aligned")
    if not -0x100000 <= imm <= 0xFFFFE:
        raise ValueError(f"JAL imm out of range: {imm}")
    imm20 = (imm >> 20) & 1
    imm10_1 = (imm >> 1) & 0x3FF
    imm11 = (imm >> 11) & 1
    imm19_12 = (imm >> 12) & 0xFF
    enc = (imm20 << 31) | (imm10_1 << 21) | (imm11 << 20) | (imm19_12 << 12)
    return (instr & 0xFFF) | enc


def patch_branch(instr, imm):
    if imm % 2:
        raise ValueError("BRANCH target not 2-aligned")
    if not -0x1000 <= imm <= 0xFFE:
        raise ValueError(f"BRANCH imm out of range: {imm}")
    imm12 = (imm >> 12) & 1
    imm10_5 = (imm >> 5) & 0x3F
    imm4_1 = (imm >> 1) & 0xF
    imm11 = (imm >> 11) & 1
    return ((instr & 0x1FFF07F)
            | (imm12 << 31) | (imm10_5 << 25) | (imm4_1 << 8) | (imm11 << 7))


def patch_hi20(instr, value):
    hi = (value + 0x800) >> 12
    return (instr & 0xFFF) | ((hi & 0xFFFFF) << 12)


def patch_lo12_i(instr, value):
    lo = value & 0xFFF
    return (instr & 0xFFFFF) | (lo << 20)


def patch_lo12_s(instr, value):
    lo = value & 0xFFF
    imm_11_5 = (lo >> 5) & 0x7F
    imm_4_0 = lo & 0x1F
    return (instr & 0x1FFF07F) | (imm_11_5 << 25) | (imm_4_0 << 7)


def patch_call(instr0, instr1, imm):
    hi = (imm + 0x800) >> 12
    lo = imm & 0xFFF
    auipc = (instr0 & 0xFFF) | ((hi & 0xFFFFF) << 12)
    jalr = (instr1 & 0xFFFFF) | (lo << 20)
    return auipc, jalr


class ObjectFile:
    def __init__(self, path):
        self.path = path
        with open(path, "rb") as f:
            self.data = f.read()
        self.elf = ELFFile(open(path, "rb"))
        self.sections = {}
        self.placed = {}
        self.global_syms = {}
        self.local_syms = {}
        self.commons = []
        self.relocs = []
        self._parse()

    def _parse(self):
        idx_to_name = {}
        for i, sec in enumerate(self.elf.iter_sections()):
            idx_to_name[i] = sec.name
            name = sec.name
            if not name:
                continue
            self.sections[name] = {
                "data": bytearray(sec.data() if sec.data() else b""),
                "size": sec["sh_size"],
                "flags": sec["sh_flags"],
                "type": sec["sh_type"],
                "addralign": max(sec["sh_addralign"] or 1, 1),
                "index": i,
            }

        for sec in self.elf.iter_sections():
            if isinstance(sec, SymbolTableSection):
                for sym in sec.iter_symbols():
                    info = {
                        "name": sym.name,
                        "value": sym["st_value"],
                        "size": sym["st_size"],
                        "shndx": sym["st_shndx"],
                        "bind": sym["st_info"]["bind"],
                        "type": sym["st_info"]["type"],
                    }
                    if info["shndx"] == "SHN_COMMON" or info["shndx"] == "SHN_COMMON":
                        self.commons.append(info)
                    elif info["bind"] == "STB_GLOBAL" or info["bind"] == "STB_WEAK":
                        self.global_syms[sym.name] = info
                    else:
                        self.local_syms[sym.name] = info

            if isinstance(sec, RelocationSection):
                target_name = idx_to_name.get(sec["sh_info"], "")
                for rel in sec.iter_relocations():
                    self.relocs.append({
                        "target": target_name,
                        "offset": rel["r_offset"],
                        "type": rel["r_info_type"],
                        "sym": rel["r_info_sym"],
                        "addend": rel["r_addend"] if rel.is_RELA() else 0,
                    })
                self._symtab = self.elf.get_section(sec["sh_link"])

        for sec in self.elf.iter_sections():
            if isinstance(sec, RelocationSection):
                self._symtab = self.elf.get_section(sec["sh_link"])
                break
        else:
            self._symtab = None

        if self._symtab is not None:
            self.sym_by_idx = list(self._symtab.iter_symbols())
        else:
            self.sym_by_idx = []


def align_up(x, a):
    return (x + a - 1) & ~(a - 1)


def is_text(name):
    return name.startswith(".text")


def is_rodata(name):
    return name.startswith(".rodata") or name.startswith(".srodata")


def is_data(name):
    return name.startswith(".data") or name.startswith(".sdata")


def is_bss(name):
    return name.startswith(".bss") or name.startswith(".sbss") or name == ".tbss"


def compile_file(src, out_o, extra_cflags):
    ext = os.path.splitext(src)[1].lower()
    cmd = [CLANG] + CFLAGS + extra_cflags + ["-c", src, "-o", out_o]
    print("Compiling:", " ".join(cmd))
    r = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
    if r.returncode != 0:
        print("STDOUT:", r.stdout)
        print("STDERR:", r.stderr)
        raise SystemExit("Compilation failed: " + src)


def link_objects(objs):
    # Place .text
    text = bytearray()
    data = bytearray()
    bss_size = 0
    placements = []  # (obj, secname, addr, kind)

    def place_group(pred, base, blob_or_none, is_bss=False):
        nonlocal bss_size
        addr = base
        for obj in objs:
            for name, sec in obj.sections.items():
                if not pred(name):
                    continue
                if sec["type"] == "SHT_NOBITS" or is_bss:
                    addr = align_up(addr, sec["addralign"])
                    obj.placed[name] = addr
                    placements.append((obj, name, addr, "bss"))
                    addr += sec["size"]
                else:
                    addr = align_up(addr, sec["addralign"])
                    obj.placed[name] = addr
                    pad = addr - (TEXT_BASE + len(text) if blob_or_none is text else DATA_BASE + RESULT_RESERVE + len(data) if False else 0)
                    placements.append((obj, name, addr, "prog"))
                    if blob_or_none is text:
                        if len(text) < addr - TEXT_BASE:
                            text.extend(b"\x00" * (addr - TEXT_BASE - len(text)))
                        text.extend(sec["data"] if sec["data"] else b"\x00" * sec["size"])
                        if len(sec["data"]) < sec["size"]:
                            text.extend(b"\x00" * (sec["size"] - len(sec["data"])))
                    elif blob_or_none is data:
                        off = addr - DATA_BASE
                        if off < 0:
                            raise SystemExit("data below DATA_BASE")
                        if len(data) < off:
                            data.extend(b"\x00" * (off - len(data)))
                        chunk = sec["data"] if sec["data"] else b"\x00" * sec["size"]
                        data.extend(chunk)
                        if len(chunk) < sec["size"]:
                            data.extend(b"\x00" * (sec["size"] - len(chunk)))
                    addr += sec["size"]
        return addr

    # Simpler placement
    taddr = TEXT_BASE
    for obj in objs:
        for name, sec in sorted(obj.sections.items(), key=lambda x: x[1]["index"] or 0):
            if not is_text(name):
                continue
            taddr = align_up(taddr, sec["addralign"])
            obj.placed[name] = taddr
            if len(text) < taddr - TEXT_BASE:
                text.extend(b"\x00" * (taddr - TEXT_BASE - len(text)))
            chunk = bytes(sec["data"])
            if len(chunk) < sec["size"]:
                chunk = chunk + b"\x00" * (sec["size"] - len(chunk))
            text.extend(chunk)
            taddr += sec["size"]

    daddr = DATA_BASE
    for obj in objs:
        for name, sec in sorted(obj.sections.items(), key=lambda x: x[1]["index"] or 0):
            if not (is_rodata(name) or is_data(name)):
                continue
            daddr = align_up(daddr, sec["addralign"])
            obj.placed[name] = daddr
            off = daddr - DATA_BASE
            if len(data) < off:
                data.extend(b"\x00" * (off - len(data)))
            chunk = bytes(sec["data"])
            if len(chunk) < sec["size"]:
                chunk = chunk + b"\x00" * (sec["size"] - len(chunk))
            data.extend(chunk)
            daddr += sec["size"]

    baddr = DATA_BASE + len(data)
    baddr = align_up(baddr, 4)
    for obj in objs:
        for name, sec in obj.sections.items():
            if not is_bss(name):
                continue
            baddr = align_up(baddr, sec["addralign"])
            obj.placed[name] = baddr
            baddr += sec["size"]
        for com in obj.commons:
            al = com["value"] or 4
            baddr = align_up(baddr, al)
            com["placed"] = baddr
            baddr += com["size"] or al

    globals_map = {}
    for obj in objs:
        for name, info in obj.global_syms.items():
            shndx = info["shndx"]
            if shndx == "SHN_UNDEF":
                continue
            if shndx == "SHN_ABS":
                globals_map[name] = info["value"]
                continue
            if shndx == "SHN_COMMON":
                for com in obj.commons:
                    if com["name"] == name:
                        globals_map[name] = com["placed"]
                        break
                continue
            # shndx is section index int
            secname = None
            for n, s in obj.sections.items():
                if s["index"] == shndx:
                    secname = n
                    break
            if secname is None:
                continue
            if secname not in obj.placed:
                continue
            globals_map[name] = obj.placed[secname] + info["value"]

    image_text = bytearray(text)
    image_data = bytearray(data)
    pcrel_hi = {}  # (obj, offset_of_hi) -> value used for lo12

    def write_at(addr, nbytes, val):
        raw = int(val).to_bytes(nbytes, "little", signed=False)
        if TEXT_BASE <= addr < TEXT_BASE + len(image_text):
            off = addr - TEXT_BASE
            image_text[off:off + nbytes] = raw
        elif DATA_BASE <= addr < DATA_BASE + len(image_data):
            off = addr - DATA_BASE
            if off + nbytes > len(image_data):
                image_data.extend(b"\x00" * (off + nbytes - len(image_data)))
            image_data[off:off + nbytes] = raw
        else:
            raise SystemExit(f"write_at unmapped {hex(addr)}")

    def read_u32(addr):
        if TEXT_BASE <= addr < TEXT_BASE + len(image_text):
            off = addr - TEXT_BASE
            return struct.unpack_from("<I", image_text, off)[0]
        if DATA_BASE <= addr < DATA_BASE + len(image_data):
            off = addr - DATA_BASE
            return struct.unpack_from("<I", image_data, off)[0]
        raise SystemExit(f"read_u32 unmapped {hex(addr)}")

    def resolve_sym(obj, rel):
        sym = obj.sym_by_idx[rel["sym"]]
        name = sym.name
        shndx = sym["st_shndx"]
        bind = sym["st_info"]["bind"]
        if shndx == "SHN_ABS":
            return sym["st_value"]
        if shndx == "SHN_UNDEF" or (bind == "STB_GLOBAL" and shndx == "SHN_UNDEF"):
            if name not in globals_map:
                raise SystemExit(f"undefined symbol: {name} in {obj.path}")
            return globals_map[name]
        if shndx == "SHN_COMMON":
            if name in globals_map:
                return globals_map[name]
            for com in obj.commons:
                if com["name"] == name:
                    return com["placed"]
            raise SystemExit("common not placed: " + name)
        if bind in ("STB_GLOBAL", "STB_WEAK") and name in globals_map:
            # Defined here or elsewhere
            secname = None
            for n, s in obj.sections.items():
                if s["index"] == shndx:
                    secname = n
                    break
            if secname and secname in obj.placed:
                return obj.placed[secname] + sym["st_value"]
            return globals_map[name]
        secname = None
        for n, s in obj.sections.items():
            if s["index"] == shndx:
                secname = n
                break
        if secname is None or secname not in obj.placed:
            if name in globals_map:
                return globals_map[name]
            raise SystemExit(f"cannot resolve {name} shndx={shndx} in {obj.path}")
        return obj.placed[secname] + sym["st_value"]

    for obj in objs:
        for rel in obj.relocs:
            rtype = rel["type"]
            if rtype in (R_RISCV_RELAX, R_RISCV_ALIGN):
                continue
            if rel["target"] not in obj.placed:
                continue
            P = obj.placed[rel["target"]] + rel["offset"]
            S = resolve_sym(obj, rel)
            A = rel["addend"]
            V = u32(S + A)

            if rtype == R_RISCV_32:
                write_at(P, 4, V)
            elif rtype == R_RISCV_SET32:
                write_at(P, 4, V)
            elif rtype == R_RISCV_ADD32:
                write_at(P, 4, u32(read_u32(P) + V))
            elif rtype == R_RISCV_SUB32:
                write_at(P, 4, u32(read_u32(P) - V))
            elif rtype == R_RISCV_32_PCREL:
                write_at(P, 4, u32(S + A - P))
            elif rtype == R_RISCV_HI20:
                instr = read_u32(P)
                write_at(P, 4, patch_hi20(instr, V))
            elif rtype == R_RISCV_LO12_I:
                instr = read_u32(P)
                write_at(P, 4, patch_lo12_i(instr, V))
            elif rtype == R_RISCV_LO12_S:
                instr = read_u32(P)
                write_at(P, 4, patch_lo12_s(instr, V))
            elif rtype == R_RISCV_PCREL_HI20:
                rel_val = S + A - P
                pcrel_hi[(id(obj), rel["offset"], rel["target"])] = (P, S + A)
                instr = read_u32(P)
                write_at(P, 4, patch_hi20(instr, u32(rel_val)))
            elif rtype == R_RISCV_PCREL_LO12_I:
                # S is address of the HI20 reloc location
                hi_p = S
                target = None
                for (oid, off, tname), (hp, tval) in pcrel_hi.items():
                    if oid == id(obj) and hp == hi_p:
                        target = tval
                        break
                if target is None:
                    # HI20 may use symbol at that location; search by P==S
                    for (oid, off, tname), (hp, tval) in pcrel_hi.items():
                        if hp == hi_p:
                            target = tval
                            break
                if target is None:
                    raise SystemExit(f"PCREL_LO12_I unpaired at {hex(P)}")
                rel_val = target - hi_p
                instr = read_u32(P)
                write_at(P, 4, patch_lo12_i(instr, u32(rel_val)))
            elif rtype == R_RISCV_PCREL_LO12_S:
                hi_p = S
                target = None
                for (oid, off, tname), (hp, tval) in pcrel_hi.items():
                    if hp == hi_p:
                        target = tval
                        break
                if target is None:
                    raise SystemExit(f"PCREL_LO12_S unpaired at {hex(P)}")
                rel_val = target - hi_p
                instr = read_u32(P)
                write_at(P, 4, patch_lo12_s(instr, u32(rel_val)))
            elif rtype in (R_RISCV_CALL, R_RISCV_CALL_PLT):
                imm = (S + A) - P
                i0 = read_u32(P)
                i1 = read_u32(P + 4)
                a, b = patch_call(i0, i1, u32(imm) if imm >= 0 else imm)
                # patch_call expects full signed imm
                a, b = patch_call(i0, i1, imm)
                write_at(P, 4, a)
                write_at(P + 4, 4, b)
            elif rtype == R_RISCV_JAL:
                imm = (S + A) - P
                instr = read_u32(P)
                write_at(P, 4, patch_jal(instr, imm))
            elif rtype == R_RISCV_BRANCH:
                imm = (S + A) - P
                instr = read_u32(P)
                write_at(P, 4, patch_branch(instr, imm))
            else:
                raise SystemExit(f"unsupported reloc type {rtype} at {hex(P)} in {obj.path}")

    if "_start" not in globals_map:
        raise SystemExit("missing _start")
    if globals_map["_start"] != 0:
        print("warning: _start is at", hex(globals_map["_start"]), "not 0")

    bss_bytes = baddr - (DATA_BASE + len(image_data))
    if bss_bytes < 0:
        bss_bytes = 0
    dmem = bytearray(RESULT_RESERVE) + bytearray(image_data) + bytearray(bss_bytes)
    if len(dmem) > DMEM_SIZE_BYTES:
        raise SystemExit(f"DMEM overflow: {len(dmem)} > {DMEM_SIZE_BYTES}")
    dmem.extend(b"\x00" * (DMEM_SIZE_BYTES - len(dmem)))
    return bytes(image_text), bytes(dmem)


def write_hex(path, blob):
    if len(blob) % 4:
        blob = blob + b"\x00" * (4 - len(blob) % 4)
    words = []
    for i in range(0, len(blob), 4):
        words.append(f"{struct.unpack_from('<I', blob, i)[0]:08x}")
    with open(path, "w") as f:
        f.write("\n".join(words) + "\n")
    print(f"Wrote {path} ({len(words)} words)")


def sources_for(kind, tests_dir):
    crt0 = os.path.join(tests_dir, "crt0.s")
    port = os.path.join(tests_dir, "port.c")
    if kind == "dhrystone":
        d = os.path.join(tests_dir, "dhrystone")
        return [crt0, port, os.path.join(d, "dhry_1.c"), os.path.join(d, "dhry_2.c")]
    if kind == "coremark":
        d = os.path.join(tests_dir, "coremark")
        return [
            crt0, port,
            os.path.join(d, "core_portme.c"),
            os.path.join(d, "core_list_join.c"),
            os.path.join(d, "core_main.c"),
            os.path.join(d, "core_matrix.c"),
            os.path.join(d, "core_state.c"),
            os.path.join(d, "core_util.c"),
        ]
    raise SystemExit("usage: compile_to_hex.py dhrystone|coremark [program.hex]")


def extra_flags(kind, tests_dir):
    flags = ["-DREG="]
    if kind == "dhrystone":
        flags += [
            "-I", os.path.join(tests_dir, "dhrystone"),
            "-DDHRY_RUNS=5",
            "-std=gnu89",
            "-Wno-implicit-function-declaration",
            "-Wno-implicit-int",
        ]
    elif kind == "coremark":
        flags += [
            "-I", os.path.join(tests_dir, "coremark"),
            "-DITERATIONS=1",
            "-DPERFORMANCE_RUN=1",
            "-DFLAGS_STR=\"-O2 -march=rv32im\"",
        ]
    return flags


def main():
    if len(sys.argv) < 2:
        print("Usage: python3 compile_to_hex.py dhrystone|coremark [program.hex]")
        sys.exit(1)
    kind = sys.argv[1]
    out_hex = sys.argv[2] if len(sys.argv) > 2 else "program.hex"
    tests_dir = os.path.dirname(os.path.abspath(__file__))
    srcs = sources_for(kind, tests_dir)
    extras = extra_flags(kind, tests_dir)

    tmpdir = tempfile.mkdtemp(prefix="riscv_link_")
    objs = []
    try:
        for src in srcs:
            base = os.path.splitext(os.path.basename(src))[0]
            out_o = os.path.join(tmpdir, base + ".o")
            compile_file(src, out_o, extras)
            objs.append(ObjectFile(out_o))
        text, dmem = link_objects(objs)
        write_hex(out_hex, text)
        data_hex = os.path.join(os.path.dirname(os.path.abspath(out_hex)) or ".", "data.hex")
        if os.path.dirname(out_hex):
            data_hex = os.path.join(os.path.dirname(os.path.abspath(out_hex)), "data.hex")
        else:
            data_hex = "data.hex"
        write_hex(data_hex, dmem)
        print(f"Linked {kind}: text {len(text)} bytes, dmem {len(dmem)} bytes")
    finally:
        for fn in os.listdir(tmpdir):
            os.remove(os.path.join(tmpdir, fn))
        os.rmdir(tmpdir)


if __name__ == "__main__":
    main()
