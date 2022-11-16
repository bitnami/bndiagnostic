#!/bin/bash

function checkConnectivity {
    local public_ip=$(curl -s myip.bitnami.com)
    local show_error=0
    for port in 22 80 443; do
        nc -zv -w5 $public_ip $port > /dev/null 2>&1
        if [ $? -ne 0 ]; then
            show_error=1
        fi
    done
    if [ $show_error -eq 1 ]; then
        no_issues=false
        format "suggest" "Server ports 22, 80 and/or 443 are not publicly accessible. Please check the following guide to open server ports for remote access:"
        format "suggest" "https://docs.bitnami.com/general/faq/administration/use-firewall/"
    fi
}

function validate {
    if [[ -d "${install_dir}" ]]; then
        echo "1";
    else
        echo "0";
    fi
}

function run {
    no_issues=true
    format "section" "${component^}"
    checkConnectivity
    addStatus "${component^}" "$no_issues"
    if $no_issues; then
        format "clear" "${no_issues}"
    fi
}