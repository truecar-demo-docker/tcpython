#!/usr/bin/env bash

export PATH=/var/cache/venv/bin:${PATH}

export TWINE_REPOSITORY_URL="https://artifactory.corp.tc/artifactory/api/pypi/tc-pypi"

readonly ARTIFACTORY_URL="https://artifactory.corp.tc/artifactory/misc-static/tcpython"

die() { echo "$*" && exit 1; }

ispydatajob() {
  python setup.py --keywords | grep -q tc-pydatajob && [[ -s Makefile ]]
}

pypackagename() {
  python setup.py --name
}

pypackageversion() {
  python setup.py --version
}

pypackage_upload() {
  if [[ ${BUILDKITE_BRANCH:-unknown} != master ]]; then
    echo "Skipping upload for non-master branch!"
    return
  fi
  [[ -z "${ARTIFACTORY_USER}" || -z "${ARTIFACTORY_PASSWORD}" ]] && return 0
  twine upload \
    --username="${ARTIFACTORY_USER}" \
    --password="${ARTIFACTORY_PASSWORD}" \
    ./dist/*.whl
}

pydatajob_upload() {
  local branch="${BUILDKITE_BRANCH:-master}"
  local name="$(pypackagename)"
  local version="$(pypackageversion)"
  local target="${name}-${version}"

  [[ "${PREPEND_BRANCH_TO_FILENAME:-true}" == true && "${branch}" != "master" ]] &&
    target="${name}-${branch}-${version}"

  (make EXTRA_INDEX_URL="https://${EXTRA_INDEX_CREDENTIALS}@pypi.build.true.sh" &&
    [[ -s "${name}.zip" ]]) || die "Failed to create ${name}.zip"

  [[ -n "${ARTIFACTORY_USER}" && -n "${ARTIFACTORY_PASSWORD}" ]] ||
    die "Missing Artifactory credentials!"

  curl -sSf -u "${ARTIFACTORY_USER}:${ARTIFACTORY_PASSWORD}" \
    -X PUT \
    -T "${name}.zip" \
    "${ARTIFACTORY_URL}/${name}/${target}.zip" ||
      die "Failed to upload ${name}.zip to Artifactory"
}

build() {
  if ispydatajob; then
    pydatajob_upload
  else
    pypackage_upload
  fi
}

run() {
  package=$1 && shift
  version=$1 && shift

  [[ -n ${package} ]] || die "Missing pacakage name!"
  [[ -n ${version} ]] || die "Missing version!"

  curl -sSL -o package.zip \
    "${ARTIFACTORY_URL}/${package}/${package}-${version}.zip" &&
    unzip -qq package.zip &&
    # show version
    python3 -m "${package}" --version
  # run
  exec python3 -m "${package}" "$@"
}

"$@"
