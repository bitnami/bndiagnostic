#!/bin/bash

function checkErrors {
    local pagespeed_errors=0;
    local other_errors=0;
    local warnings=0
    local comp_dir="${install_dir}/apache2"
    local apache_log="${comp_dir}/logs/error_log"
    local apache_conf="${comp_dir}/conf/httpd.conf"
    if [ -f "$apache_log" ]; then
        local pagespeed_errors=$(filterLog "${apache_log}" "pagespeed:error" 1)
        local cert_mismatch_error=$(filterLog "${apache_log}" "key do not match" 1)
        local other_errors=$(filterLog "${apache_log}" "emerg|alert|crit|error" 3 "pagespeed:error|plugin|key do not match")
        if [ ! -z "$pagespeed_errors" ]; then
            no_issues=false
            format "suggest" "Found recent Pagespeed related error messages in the Apache error log:$(format "wrap" "${pagespeed_errors}")We suggest disabling pagespeed and check if that improves the behavior. Please check the following guide to disable Pagespeed:"
            format "link" "https://docs.bitnami.com/general/apps/wordpress/administration/use-pagespeed/#disable-pagespeed"
        fi
        if [ ! -z "$cert_mismatch_error" ]; then
            no_issues=false
            format "suggest" "The SSL certificate and key do not seem to match:$(format "wrap" "${cert_mismatch_error}")The following guide shows how to generate a new certificate:"
            format "link" "https://docs.bitnami.com/general/apps/wordpress/administration/enable-https-ssl-apache/"
        fi
        if [ ! -z "$other_errors" ]; then
            no_issues=false
            format "suggest" "Found recent error or warning messages in the Apache error log.$(format "wrap" "${other_errors}")Please check the following guide to troubleshoot server issues:"
            format "link" "https://docs.bitnami.com/general/apps/wordpress/troubleshooting/debug-errors-apache/"
        fi
    fi
    if [ -f "${apache_conf}" ]; then
        if command -v apachectl >/dev/null 2>&1; then
            apachectl -t -f "${apache_conf}" 2>/tmp/error
            apache_conf_error=$(cat /tmp/error)
            if [[ ! "$apache_conf_error" =~ "Syntax OK" ]]; then
                if [ "$apache_conf_error" != "*Could not reliably determine*" ]; then
                    apache_conf_error="$(cat /tmp/error)"
                    no_issues=false
                    format "suggest" "The Apache configuration has errors:$(format "wrap" "${apache_conf_error}")Please check the configuration."
                fi
            fi
            rm /tmp/error >/dev/null 2>&1;
        fi
    fi
}
function checkMostActive {
    local access_log="${install_dir}/apache2/logs/access_log"
    local requests_total="100000"
    local check_num="10"
    local isHighNumber=0;
    if [ -f "$access_log" ]; then
        local unique_entries=$(tail -n "${requests_total}" "${access_log}" | grep -v '127.0.0.1'| awk '{print $1}' | sort | uniq -c | awk '{print $1}'| sort -nr | head -n "${check_num}")
        while read -r entry_number; do
            local percentage=$(( (entry_number*100) / requests_total ))
            if [ ! -z "$entry_number" ]  && [ "$percentage" -gt 10 ]; then
                isHighNumber=1;
                no_issues=false
            fi
        done <<< "$unique_entries"
        if is_boolean_yes "$isHighNumber"; then
            format "suggest" "A high number of incoming requests originate from one or more unique IP addresses. This could indicate a bot attack. The following guide shows how to check for and block suspicious IP addresses."
            format "link" "https://docs.bitnami.com/general/apps/wordpress/troubleshooting/deny-connections-bots-apache/"
        fi
    fi
}

function checkRedirectLoop {
    local machine_ip=$(curl -ss myip.bitnami.com);
    curl -LIss --max-redirs 10 --connect-timeout 10 "$machine_ip" > /tmp/redirections 2>/dev/null;
    local redirection_count=$(cat /tmp/redirections | grep HTTP | wc -l)
    if [ $redirection_count -gt 10 ]; then
      no_issues=false
      format "suggest" "Incoming requests are being redirected too many times. You can check it with this command:"
      format "code" "curl -LI --connect-timeout 10 --max-redirs 10 $machine_ip"
      format "suggest" "The following guide shows how to properly redirect to HTTPS and can be useful in this case:"
      format "link" "https://docs.bitnami.com/general/apps/wordpress/administration/force-https-apache/"
    fi
}

function checkSystemApache {
    local system_apache_is_running=$(ps aux | grep apache | grep -v bitnami | grep -v grep | wc -l)
    local system_apache_example=$(ps aux | grep apache  | head -2)
    if [ $system_apache_is_running -gt 0 ]; then
        format "suggest" "System Apache is running:$(format "wrap" "${system_apache_example}") If Bitnami Apache isn't starting this is the most likely cause. Please run the following command to stop it:$(format "code" "sudo systemctl disable apache2 && sudo systemctl stop apache2")"
    fi
}

function validate {
    if [[ -d "${install_dir}/apache2" ]]; then
        echo "1";
    else
        echo "0";
    fi
}

function run {
    no_issues=true
    format "section" "${component^}"
    checkErrors
    checkMostActive
    checkSystemApache
    checkRedirectLoop
    addStatus "${component^}" "$no_issues"
    if $no_issues; then
        format "clear" "${no_issues}"
    fi
}
