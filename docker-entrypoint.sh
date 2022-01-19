#!/bin/sh

export LW_ACCOUNT_NAME=${INPUT_LW_ACCOUNT_NAME}
export LW_ACCESS_TOKEN=${INPUT_LW_ACCESS_TOKEN}

# Disable update prompt for lw-scanner if newer version is available unless explicitly set
export LW_SCANNER_DISABLE_UPDATES=${LW_SCANNER_DISABLE_UPDATES:-true}

# Add parameters based on arguments
export SCANNER_PARAMETERS=""
if [ ${INPUT_SCAN_LIBRARY_PACKAGES} = "false" ]; then
    export SCANNER_PARAMETERS="${SCANNER_PARAMETERS} --disable-library-package-scanning"
fi
if [ ${INPUT_SAVE_RESULTS_IN_LACEWORK} = "true" ]; then
    export SCANNER_PARAMETERS="${SCANNER_PARAMETERS} --save"
fi
if [ ${INPUT_SAVE_BUILD_REPORT} = "true" ]; then
    export SCANNER_PARAMETERS="${SCANNER_PARAMETERS} --html"
fi
if [ ! -z "${INPUT_BUILD_REPORT_FILE_NAME}" ]; then
    export SCANNER_PARAMETERS="${SCANNER_PARAMETERS} --html-file ${INPUT_BUILD_REPORT_FILE_NAME}"
fi
if [ ${INPUT_USE_POLICY} = "true" ]; then
    export SCANNER_PARAMETERS="${SCANNER_PARAMETERS} --policy --fail-on-violation-exit-code 1"
fi

# Remove old scanner evaluation, if cached somehow
rm ${GITHUB_WORKSPACE}/evaluations/${INPUT_IMAGE_NAME}/${INPUT_IMAGE_TAG}/evaluation_*.json &>/dev/null || true

# Run scanner
/usr/local/bin/lw-scanner image evaluate ${INPUT_IMAGE_NAME} ${INPUT_IMAGE_TAG} --build-plan ${GITHUB_REPOSITORY} --build-id ${GITHUB_RUN_ID} --data-directory ${GITHUB_WORKSPACE} ${SCANNER_PARAMETERS} --docker-server ${INPUT_DOCKER_REGISTRY} --docker-username ${INPUT_DOCKER_USERNAME} --docker-password ${INPUT_DOCKER_PASSWORD
export LW_SCANNER_EXIT_CODE=$?

# Exit if check is failed and policy feature not used
if [ ${INPUT_USE_POLICY} = "false" ] && [ ${LW_SCANNER_EXIT_CODE} != 0 ]; then
    echo "Vulnerability scan failed. Failing action as security can not be guaranteed. Exiting with code 1"
    exit 1
fi

# Check if needed to check build and policy feature not used
if [ ${INPUT_USE_POLICY} = "false" ] && [ ${INPUT_FAIL_BUILD} = "true" ]; then
# Check if vulnerabilites related to the severity threshold are found and if so fail action
  case $INPUT_SEVERITY_THRESHOLD in
	fixable)
        FIXABLE_VULNS_FOUND=$(cat ${GITHUB_WORKSPACE}/evaluations/${INPUT_IMAGE_NAME}/${INPUT_IMAGE_TAG}/evaluation_*.json | jq '.cve.fixable_vulnerabilities')
        if [ ${FIXABLE_VULNS_FOUND} -ge 1 ]; then
            echo "${FIXABLE_VULNS_FOUND} fixable vulnerabilities found. Exiting with code 1"
            exit 1
        fi
		;;
	critical)
        CRITICAL_VULNS_FOUND=$(cat ${GITHUB_WORKSPACE}/evaluations/${INPUT_IMAGE_NAME}/${INPUT_IMAGE_TAG}/evaluation_*.json | jq '.cve.critical_vulnerabilities')
        if [ ${CRITICAL_VULNS_FOUND} -ge 1 ]; then
            echo "${CRITICAL_VULNS_FOUND} critical vulnerabilities found. Exiting with code 1"
            exit 1
        fi
		;;
	high)
        HIGH_VULNS_FOUND=$(cat ${GITHUB_WORKSPACE}/evaluations/${INPUT_IMAGE_NAME}/${INPUT_IMAGE_TAG}/evaluation_*.json | jq '.cve.high_vulnerabilities')
        if [  ${HIGH_VULNS_FOUND} -ge 1 ]; then
            echo "${HIGH_VULNS_FOUND} high vulnerabilities found. Exiting with code 1"
            exit 1
        fi
		;;
	medium)
        MEDIUM_VULNS_FOUND=$(cat ${GITHUB_WORKSPACE}/evaluations/${INPUT_IMAGE_NAME}/${INPUT_IMAGE_TAG}/evaluation_*.json | jq '.cve.medium_vulnerabilities')
        if [  ${MEDIUM_VULNS_FOUND} -ge 1 ]; then
            echo "${MEDIUM_VULNS_FOUND} medium vulnerabilities found. Exiting with code 1"
            exit 1
        fi
		;;
	low)
        LOW_VULNS_FOUND=$(cat ${GITHUB_WORKSPACE}/evaluations/${INPUT_IMAGE_NAME}/${INPUT_IMAGE_TAG}/evaluation_*.json | jq '.cve.low_vulnerabilities')
        if [  ${LOW_VULNS_FOUND} -ge 1 ]; then
            echo "${LOW_VULNS_FOUND} low vulnerabilities found. Exiting with code 1"
            exit 1
        fi
		;;
	info)
        INFO_VULNS_FOUND=$(cat ${GITHUB_WORKSPACE}/evaluations/${INPUT_IMAGE_NAME}/${INPUT_IMAGE_TAG}/evaluation_*.json | jq '.cve.INFO_vulnerabilities')
        if [  ${INFO_VULNS_FOUND} -ge 1 ]; then
            echo "${INFO_VULNS_FOUND} info vulnerabilities found. Exiting with code 1"
            exit 1
        fi
		;;
  esac
else
    exit ${LW_SCANNER_EXIT_CODE}
fi