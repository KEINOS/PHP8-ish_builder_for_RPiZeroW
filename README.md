# PHP8 builder for RPiZeroW Buster

**Shell script to build PHP8-ish (latest master of PHP) with JIT enabled from source** for Stretch and Buster on RaspberryPi Zero W.

## Download

- `https://keinos.github.io/PHP8-ish_builder_for_RPiZeroW/build_php8.sh`

```bash
curl https://keinos.github.io/PHP8-ish_builder_for_RPiZeroW/build_php8.sh -O build.sh && chmod +x $_
```

## Usage (How to run builder)

```bash
time sudo ./build.sh
```

## Requirements

- Raspberry Pi Zero W (Tested: BCM2835/9000c1)
- Raspbian
    - Stretch (^[2019-04-08-raspbian-stretch-lite](https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-04-09/).zip)
    - Buster (^[2019-09-26-raspbian-buster-lite](https://downloads.raspberrypi.org/raspbian_lite/images/raspbian_lite-2019-09-30/).zip)
- Lots of swap size (Check by: `swapon -s`)
