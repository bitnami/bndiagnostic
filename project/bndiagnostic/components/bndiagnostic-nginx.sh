#!/bin/bash

function checkErrors {
    local pagespeed_errors=0;
    local other_errors=0;
    local warnings=0
    local comp_dir="${install_dir}/nginx"
    local nginx_log="${comp_dir}/logs/error.log"
    local nginx_conf="${comp_dir}/conf/nginx.conf"
    local pagespeed_errors=$(filterLog "${nginx_log}" "pagespeed" 1 "info|warn")
    local cert_mismatch_error=$(filterLog "${nginx_log}" "key values mismatch" 1)
    local other_errors=$(filterLog "${nginx_log}" "emerg|alert|crit|error" 3 "pagespeed|key values mismatch")
    if [ ! -z "$pagespeed_errors" ]; then
        no_issues=false
        format "suggest" "Found recent Pagespeed related error messages in the Nginx error log:$(format "wrap" "${pagespeed_errors}")We suggest disabling pagespeed and check if that improves the behavior. Please check the following guide to disable Pagespeed:"
        format "link" "https://docs.bitnami.com/general/apps/mattermost/administration/use-pagespeed-nginx/"
    fi
    if [ ! -z "$cert_mismatch_error" ]; then
        no_issues=false
        format "suggest" "The SSL certificate and key do not seem to match:$(format "wrap" "${cert_mismatch_error}")The following guide shows how to generate a new certificate:"
        format "link" "https://docs.bitnami.com/general/apps/wordpress/administration/enable-https-ssl-apache/"
    fi
    if [ ! -z "$other_errors" ]; then
        no_issues=false
        format "suggest" "Found recent error or warning messages in the Nginx error log.$(format "wrap" "${other_errors}")Please check the following guide to troubleshoot server issues:"
        format "link" "https://docs.bitnami.com/general/infrastructure/nginx/troubleshooting/"
    fi
    if [ -f ${nginx_conf} ]; then
        if command -v nginx >/dev/null 2>&1; then
            nginx -t -c "${nginx_conf}" 2>/tmp/error
            nginx_conf_error=$(cat /tmp/error)
            if [[ ! "$nginx_conf_error" =~ "syntax is ok" ]]; then
                nginx_conf_error="$(cat /tmp/error)"
                no_issues=false
                format "suggest" "The Nginx configuration has errors:$(format "wrap" "${nginx_conf_error}")Please check the configuration."
            fi
            rm /tmp/error >/dev/null 2>&1;
        fi
    fi
}

function checkRedirectLoop {
    local machine_ip=$(curl -ss myip.bitnami.com);
    curl -LIss --connect-timeout 10 --max-redirs 10 "$machine_ip" > /tmp/redirections 2>/dev/null;
    local redirection_count=$(cat /tmp/redirections | grep HTTP | wc -l)
    if [ $redirection_count -gt 10 ]; then
      no_issues=false
      format "suggest" "Incoming requests are being redirected too many times. You can check it with this command:"
      format "code" "curl -LI --connect-timeout 10 --max-redirs 10 $machine_ip"
      format "suggest" "The following guide shows how to properly redirect to HTTPS and can be useful in this case:"
      format "link" "https://docs.bitnami.com/general/apps/wordpress/administration/force-https-apache/"
    fi
}

function checkSystemNginx {
    local system_nginx_is_running=$(ps aux | grep 'nginx: master process' | grep -v bitnami | grep -v grep | wc -l)
    system_nginx_example=$(ps aux | grep nginx  | head -1)
    if [ $system_nginx_is_running -gt 0 ]; then
        format "suggest" "System Nginx is running:$(format "wrap" "${system_nginx_example}") If Bitnami Nginx isn't starting this is the most likely cause. Please run the following command to stop it:$(format "code" "sudo systemctl disable nginx && sudo systemctl stop nginx")"
    fi
}

function validate {
    if [[ -d "${install_dir}/nginx" ]]; then
        echo "1";
    else
        echo "0";
    fi
}

function run {
    no_issues=true
    format "section" "${component^}"
    checkErrors
    checkSystemNginx
    checkRedirectLoop
    addStatus "${component^}" "$no_issues"
    if $no_issues; then
        format "clear" "${no_issues}"
    fi
}
