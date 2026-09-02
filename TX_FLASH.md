# TX Flash Procedures

The TX branch uses the legacy tegraflash image type from Jetson Linux R32.7.6.
Build a board image with its kas board file, then use the generated package in
that machine's deploy directory.

```sh
make build jetson-tx1-devkit
make build jetson-tx2-devkit
```

Each tegraflash package contains a generated `doflash.sh` selected by the
upstream machine configuration. Run it from the extracted package with the
target connected in recovery mode. Do not substitute a package generated for a
different machine.

## Board Commands

- TX1 P2180/P2597: `make build jetson-tx1-devkit`, then run its `doflash.sh`.
- TX2 P3310/P2771: `make build jetson-tx2-devkit`, then run its `doflash.sh`.
- TX2 4GB P3489/P2771: `make build jetson-tx2-devkit-4gb`, then run its `doflash.sh`.
- TX2i P3489 Storm/P2771: `make build jetson-tx2-devkit-tx2i`, then run its `doflash.sh`.
- TX2 NX P3636/P3509: `make build jetson-xavier-nx-devkit-tx2-nx`, then run its `doflash.sh`.
- Nano SD P3448/P3449: `make build jetson-nano-devkit`, then run its `dosdcard.sh`.
- Nano eMMC P3448 SKU 0002/P3449: `make build jetson-nano-devkit-emmc`, then run its `doflash.sh`.
- Nano 2GB P3448 SKU 0003/P3542: `make build jetson-nano-2gb-devkit`, then run its `dosdcard.sh`.

The generated scripts and board-specific XML selections are authoritative. The
flash package has not been exercised against physical hardware in this
repository validation.