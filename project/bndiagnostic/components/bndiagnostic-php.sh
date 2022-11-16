#!/bin/bash
function checkErrors {
    local comp_dir="${install_dir}/php"
    local log_file="${comp_dir}/logs/php-fpm.log"
    if [ ! -f "${log_file}" ]; then
        local log_file="${comp_dir}/var/log/php-fpm.log"
    fi
    if [ -f "${log_file}" ]; then
        local max_children_errors=$(filterLog "${log_file}" "reached max_children setting" 1)
        local memory_errors=$(filterLog "${log_file}" "Cannot allocate memory" 1)
        local pool_buzy_errors=$(filterLog "${log_file}" "//[pool www//] seems busy" 1)
        if [[ ! -z "${max_children_errors}" ]]; then
            no_issues=false
            format "suggest" "The following error appears in the $(format "path" "$log_file"):$(format "wrap" "$(echo "${max_children_errors}")")This error usually indicates PHP script execution is slow due to busy server resouces or buggy scripts. Please check the following guide to increase the number of PHP-FPM child processes:"
            format "link" "https://docs.bitnami.com/general/apps/wordpress/configuration/configure-phpfpm-processes/"
        fi
        if [[ ! -z "${pool_buzy_errors}" ]]; then
            no_issues=false
            format "suggest" "The following error appears in the $(format "path" "$log_file"):$(format "wrap" "$(echo "${pool_buzy_errors}")")Please check the following guide to configure PHP-FPM processes:"
            format "link" "https://docs.bitnami.com/general/apps/wordpress/configuration/configure-phpfpm-processes/"
        fi
        if [[ ! -z "${memory_errors}" ]]; then
            no_issues=false
            format "suggest" "The following error appears in the $(format "path" "$log_file"):$(format "wrap" "$(echo "${memory_errors}")")This error  indicates there is a problem with the memory limit in PHP. Please check the following guide to increase the number of PHP-FPM child processes:"
            format "link" "https://docs.bitnami.com/general/apps/akeneo/administration/increase-memory-limit/"
        fi
    fi
}

function validate {
    if [[ -d "${install_dir}/php" ]]; then
        echo "1";
    else
        echo "0";
    fi
}

function run {
    no_issues=true
    format "section" "${component^}"
    checkErrors
    addStatus "${component^}" "$no_issues"
    if $no_issues; then
        format "clear" "${no_issues}"
    fi
}
