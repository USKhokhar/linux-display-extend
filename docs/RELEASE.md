# Release Guide

## Goal

This document describes the expected release workflow for Linux Display Extend.

## Before Cutting A Release

1. Update `VERSION`.
2. Update `CHANGELOG.md`.
3. Run `make test`.
4. Run manual Linux X11 validation for the runtime flow.
5. Run `make package`.
6. Review the generated package tree under `build/package/`.

## Release Checklist

- version and changelog are aligned
- README still matches the supported install path
- CONTRIBUTING and docs still match the current architecture
- no duplicate runtime logic was reintroduced
- no insecure defaults were reintroduced