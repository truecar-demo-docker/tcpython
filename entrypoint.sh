#!/usr/bin/env bash

export PATH=/var/cache/venv/bin:${PATH}

export TWINE_REPOSITORY_URL="https://artifactory.corp.tc/artifactory/api/pypi/tc-pypi"

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
  # --secret is just a prefix added to the object path
  s3pypi --force --no-sdist --private --secret packages \
    --bucket "${S3_BUCKET}" ||
    die "Failed to publish package: $(pypackagename)"
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
  aws s3 cp "${name}.zip" \
    "s3://${S3_BUCKET}/datajobs/${name}/${target}.zip" ||
    die "Failed to copy ${name}.zip to s3://${S3_BUCKET}/datajobs/"
}

build() {
  if ispydatajob; then
    pydatajob_upload
  else
    pypackage_upload
  fi
}

run() {
  local DATA_JOB_URL="https://${EXTRA_INDEX_CREDENTIALS}@datajobs.build.true.sh"

  package=$1 && shift
  version=$1 && shift

  [[ -n ${package} ]] || die "Missing pacakage name!"
  [[ -n ${version} ]] || die "Missing version!"

  curl -sSL -o package.zip \
    "${DATA_JOB_URL}/${package}/${package}-${version}.zip" &&
    unzip -qq package.zip &&
    # show version
    python3 -m "${package}" --version
  # run
  exec python3 -m "${package}" "$@"
}

"$@"
