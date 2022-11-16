#!/bin/bash

function checkPermissions {
    local comp_dir;
    local wrong_permissions;
    local perm_user;
    local perm_group;
    local perm_others;
    local count;
    wrong_permissions=false
    comp_dirs="${install_dir}/apps/wordpress/htdocs ${installdir}/wordpress/wp-content /bitnami/wordpress"
    perm_user=$(find ${comp_dirs} -user daemon ! -perm /u=w 2>/dev/null| wc -l)
    perm_group=$(find ${comp_dirs} ! -name wp-config.php ! -user daemon -group daemon ! -perm /g=w 2>/dev/null | wc -l)
    perm_others=$(find "${comp_dirs}" ! -user daemon ! -group daemon ! -perm /o=w 2>/dev/null | wc -l)
    count=$(( perm_user + perm_group + perm_others ))
    if [[ "$count" -gt 0 ]]; then
        no_issues=false
        wrong_permissions=true
    fi
    if $wrong_permissions; then
        format "suggest" "Some files don't have the expected permissions Please check the following guide:"
        format "link" "https://docs.bitnami.com/general/apps/wordpress/administration/understand-file-permissions/"
    fi
}

function checkDomain {
    local comp_dir;
    local domain_not_configured;
    local conf_file;
    local cert_valid;
    local domain;
    comp_dir="${install_dir}/apps/wordpress/htdocs"
    domain_not_configured=false
    conf_file="${comp_dir}/wp-config.php"
    cert=$(find /opt/bitnami/apache2/conf/*.crt 2>/dev/null | head -1)
    if command -v openssl > /dev/null 2>&1 && [[ -f "$cert" ]]; then
        cert_valid=$(openssl x509 -subject -issuer -noout -in "$cert" 2>/dev/null | grep -c example)
        if [[ $cert_valid == 0 && -f "$conf_file" ]]; then
            domain=$(grep -c "^define..WP_ITURL.*http" < "$conf_file")
            if [[ $domain == 0 ]]; then
                domain_not_configured=true
                no_issues=false
            fi
        fi
    fi
    if $domain_not_configured; then
        format "suggest" "The WordPress domain does not seem to be configured. Please check the following guide:"
        format "link" "https://docs.bitnami.com/general/apps/wordpress/administration/configure-domain/"
    fi
}

function checkApache {
    local apache_log;
    local plugin_errors_example;
    local plugin_errors;
    apache_log="${install_dir}/apache2/logs/error_log"
    if [[ -f "$apache_log" ]]; then
        plugin_errors=$(filterLog "${apache_log}" "plugin" 1 "pagespeed|info|warning")
        if [ ! -z "$plugin_errors" ]; then
            no_issues=false
            format "suggest" "Found recent WordPress plugin related error messages in the Apache error log.$(format "wrap" "$plugin_errors")Please check the following guide to deactivate plugins:"
            format "link" "https://developer.wordpress.org/cli/commands/plugin/deactivate/"
        fi
    fi
}

function checkNginx {
    local nginx_log="${install_dir}/nginx/logs/error.log"
    if [[ -f "$nginx_log" ]]; then
        plugin_errors=$(filterLog "${nginx_log}" "plugin" 1 "pagespeed|info|warning")
        if [ ! -z "$plugin_errors" ]; then
            no_issues=false
            format "suggest" "Found recent WordPress plugin related error messages in the Nginx error log.$(format "wrap" "$plugin_errors")Please check the following guide to deactivate plugins:"
            format "link" "https://developer.wordpress.org/cli/commands/plugin/deactivate/"
        fi
    fi
}

function validate {
    if [[ -d "${install_dir}/apps/wordpress/wp-content" ]]; then
        echo "1";
    elif [[ -d "${install_dir}/wordpress/wp-content" ]]; then
        echo "1";
    else
        echo "0";
    fi
}

function run {
    no_issues=true
    format "section" "${component^}"
    checkPermissions
    checkDomain
    checkApache
    checkNginx
    addStatus "${component^}" "$no_issues"
    if $no_issues; then
        format "clear" "${no_issues}"
    fi
}
