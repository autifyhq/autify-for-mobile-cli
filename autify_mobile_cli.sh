#!/bin/bash
#
# Upload to Autify for Mobile
set -e

readonly API_BASE_ADDRESS="https://mobile-app.autify.com/api/v1"
readonly WORKING_DIR="./"
readonly ZIP_NAME="upload.zip"
readonly AVAILAVLE_ARCH="x86_64"

info() {
  echo -e "$1"
}

success() {
  echo -e "\033[00;32m $1 \033[0m"
}

error() {
  echo -e "\033[00;31m $1 \033[0m"
}

create_app_zip() {
  cp -r "${AUTIFY_APP_DIR_PATH}" "${WORKING_DIR}"

  APP_ZIP_PATH="./${ZIP_NAME}"
  APP_NAME=$(basename "${AUTIFY_APP_DIR_PATH}")

  info "create zip file"
  zip -r "${APP_ZIP_PATH}" "${APP_NAME}"
}

is_exist_xcrun() {
  EXIST_XCRUN=true
  if type "xcrun" > /dev/null 2>&1; then
    EXIST_XCRUN=true
  else
    EXIST_XCRUN=false
  fi

  echo $EXIST_XCRUN
}

validate_app_arch() {
  if $(is_exist_xcrun) ; then
    APP_FILE_NAME=$(basename "${AUTIFY_APP_DIR_PATH}")
    BINARY_NAME=$(echo "${APP_FILE_NAME}" | sed 's/.app//')
    ARCH_INFO=$(xcrun lipo -info "${AUTIFY_APP_DIR_PATH}/${BINARY_NAME}")

    if [ "$(echo ${ARCH_INFO} | grep ${AVAILAVLE_ARCH} )" ] ;then
      info "Architecture is ok"
    else
      error "Unsupported architecture（${AVAILAVLE_ARCH} only）"
      exit 1
    fi
  else
    info "Skip checking architecture"
  fi
}

main() {
  validate_app_arch
  create_app_zip

  TOKEN_HEADER="Authorization: Bearer ${AUTIFY_UPLOAD_TOKEN}"
  API_UPLOAD_ADDRESS="${API_BASE_ADDRESS}/projects/${AUTIFY_PROJECT_ID}/builds"
  RESPONSE=$(curl -X POST "${API_UPLOAD_ADDRESS}" -H "accept: application/json" -H "${TOKEN_HEADER}" -H "Content-Type: multipart/form-data" -F "file=@${APP_ZIP_PATH};type=application/zip" -w '\n%{http_code}' -s)

  # http status
  HTTP_STATUS=$(echo "$RESPONSE" | tail -n 1)
  # body
  BODY=$(echo "$RESPONSE" | sed '$d')
  # set env
  envman add --key "AUTIFY_UPLOAD_STEP_RESULT_JSON" --value "$BODY"

  if [[ "$HTTP_STATUS" != "201" ]]; then
    error "$BODY"
    exit 1
  fi

  success "$BODY"
}

# parameters
info "parameters:"
info "* upload_token: ${AUTIFY_UPLOAD_TOKEN}"
info "* project_id: ${AUTIFY_PROJECT_ID}"
info "* app_dir_path: ${AUTIFY_APP_DIR_PATH}"

# run
main "$@"
