#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

NAME="$(python3 - <<'PY'
from pathlib import Path
import re

text = Path("pyproject.toml").read_text(encoding="utf-8")
match = re.search(r'^name\s*=\s*"([^"]+)"', text, re.M)
if not match:
    raise SystemExit("Could not determine project name from pyproject.toml")
print(match.group(1))
PY
)"
VERSION="$(python3 - <<'PY'
from pathlib import Path
import re

text = Path("pyproject.toml").read_text(encoding="utf-8")
match = re.search(r'^version\s*=\s*"([^"]+)"', text, re.M)
if not match:
    raise SystemExit("Could not determine version from pyproject.toml")
print(match.group(1))
PY
)"

echo "Building ${NAME} ${VERSION} from ${ROOT_DIR}"

if command -v makepkg >/dev/null 2>&1; then
  echo "Detected Arch packaging tools."
  TARBALL="${NAME}-${VERSION}.tar.gz"
  STAGING_DIR="$(mktemp -d)"
  rm -f "$TARBALL"
  find . -name "__pycache__" -type d -prune -exec rm -rf {} +
  find . -name "*.pyc" -delete
  cp -a . "${STAGING_DIR}/${NAME}-${VERSION}"
  rm -rf "${STAGING_DIR:?}/${NAME}-${VERSION}/.git"
  find "${STAGING_DIR:?}/${NAME}-${VERSION}" -name "__pycache__" -type d -prune -exec rm -rf {} +
  find "${STAGING_DIR:?}/${NAME}-${VERSION}" -name "*.pyc" -delete
  rm -f "${STAGING_DIR:?}/${NAME}-${VERSION}/${TARBALL}"
  tar -C "$STAGING_DIR" -czf "$TARBALL" "${NAME}-${VERSION}"
  rm -rf "$STAGING_DIR"
  makepkg -sf
  echo
  echo "Built package(s):"
  ls -1 "${NAME}-${VERSION}"-*.pkg.tar.*
  exit 0
fi

if command -v dpkg-buildpackage >/dev/null 2>&1; then
  echo "Detected Debian/Ubuntu packaging tools."
  ORIG_TARBALL="../${NAME}_${VERSION}.orig.tar.gz"
  rm -f "$ORIG_TARBALL"
  find . -name "__pycache__" -type d -prune -exec rm -rf {} +
  find . -name "*.pyc" -delete
  tar -czf "$ORIG_TARBALL" \
    --exclude .git \
    --exclude debian \
    --exclude __pycache__ \
    --exclude '*.pyc' \
    --exclude "$(basename "$ORIG_TARBALL")" \
    --transform "s,^\.,${NAME}-${VERSION}," .
  dpkg-buildpackage -us -uc
  echo
  echo "Built package(s):"
  ls -1 ../"${NAME}"_"${VERSION}"-*.deb
  exit 0
fi

if command -v rpmbuild >/dev/null 2>&1; then
  echo "Detected RPM packaging tools."
  TARBALL="${NAME}-${VERSION}.tar.gz"
  STAGING_DIR="$(mktemp -d)"
  rm -f "$TARBALL"
  find . -name "__pycache__" -type d -prune -exec rm -rf {} +
  find . -name "*.pyc" -delete
  cp -a . "${STAGING_DIR}/${NAME}-${VERSION}"
  rm -rf "${STAGING_DIR:?}/${NAME}-${VERSION}/.git"
  rm -rf "${STAGING_DIR:?}/${NAME}-${VERSION}/__pycache__"
  find "${STAGING_DIR:?}/${NAME}-${VERSION}" -name "__pycache__" -type d -prune -exec rm -rf {} +
  find "${STAGING_DIR:?}/${NAME}-${VERSION}" -name "*.pyc" -delete
  rm -f "${STAGING_DIR:?}/${NAME}-${VERSION}/${TARBALL}"
  tar -C "$STAGING_DIR" -czf "$TARBALL" "${NAME}-${VERSION}"
  rm -rf "$STAGING_DIR"
  rpmbuild -ta "$TARBALL"
  echo
  echo "Built package(s):"
  ls -1 "${HOME}/rpmbuild/RPMS/noarch/${NAME}-${VERSION}"-*.rpm
  exit 0
fi

echo "No supported package builder found."
echo "Install one of:"
echo "  Arch: makepkg base-devel python-build python-installer python-setuptools"
echo "  Debian/Ubuntu: dpkg-buildpackage debhelper dh-python pybuild-plugin-pyproject"
echo "  Fedora/RHEL: rpmbuild pyproject-rpm-macros python3-devel"
exit 1
