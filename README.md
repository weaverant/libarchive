# libarchive Static Build for Windows

Static build of [libarchive](https://github.com/libarchive/libarchive) with all major compression formats for Windows x64.

## Built Tools

| Tool | Description |
|------|-------------|
| `bsdtar.exe` | Full-featured tar implementation |
| `bsdcpio.exe` | cpio archive tool |
| `bsdcat.exe` | Decompression tool (like zcat, bzcat, xzcat) |

## Compression Support

- gzip (zlib 1.3)
- bzip2 (1.1.0)
- xz/lzma (5.6.3)
- lz4 (1.10.0)
- zstd (1.5.5)
- Encrypted ZIP (Windows CNG)

## Building

### Requirements

- Windows 10/11
- Visual Studio 2022 (Community or higher)
- Internet connection (to download dependencies)

### Build Commands

```batch
# Build everything (dependencies + libarchive)
build_static.cmd all

# Or step by step:
build_static.cmd deplibs    # Download and build dependencies
build_static.cmd configure  # Configure libarchive
build_static.cmd build      # Build libarchive
```

### Output

Static binaries are installed to `install_static\bin\`.

## Usage Examples

```batch
# Create a tar.gz archive
bsdtar -czvf archive.tar.gz folder/

# Extract a zip file
bsdtar -xvf archive.zip

# Extract a 7z file
bsdtar -xvf archive.7z

# List contents of an archive
bsdtar -tvf archive.tar.xz

# Decompress a file
bsdcat file.gz > file
```

## License

libarchive is distributed under the BSD license. See `libarchive/COPYING` for details.
