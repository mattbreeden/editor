package util

import "core:mem"
import "core:os"

foreign import libc "system:c"

PROT_READ :: 0x1;

MAP_PRIVATE :: 0x2;

MAP_FAILED :: ~uintptr(0);

foreign libc {
    @(link_name="mmap") _unix_mmap :: proc(addr: rawptr, length: int, prot: int,
                                           flags: int, fd: os.Handle,
                                           offset: int) -> rawptr ---;
    memchr :: proc(s: rawptr, c: u8, n: int) -> rawptr ---;
}

mmap :: proc(fd: os.Handle) -> ([]u8, os.Errno) {
    i64file_size, err := os.file_size(fd);
    // This shouldn't cause errors?
    // i64 is to handle negative offsets from lseek64(2).
    // Since the size will always be positive,
    // even on a 32 bit system this should always be large enough
    file_size := cast(int)i64file_size;

    if err != 0 {
        return nil, err;
    }

    data := _unix_mmap(nil, file_size, PROT_READ, MAP_PRIVATE, fd, 0);
    if data == rawptr(MAP_FAILED) {
        return nil, 1;
    }

    return transmute([]byte)mem.Raw_Slice{data, file_size}, 0;
}
