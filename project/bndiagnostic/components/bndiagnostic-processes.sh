#!/bin/bash
function checkProcesses {
    if [ -f "$install_dir/ctlscript.sh" ]; then
        local ctlStatus=$($install_dir/ctlscript.sh status | grep "not running")
        if [ ! -z "$ctlStatus" ]; then
            no_issues=false
            format "suggest" "One or more component's processes are not running:$(format "wrap" "${ctlStatus}")You can try to restart the process with the following command:"
            format "code" "sudo $install_dir/ctlscript.sh start COMPONENT_NAME"
        fi
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
    checkProcesses
    addStatus "${component^}" "$no_issues"
    if $no_issues; then
        format "clear" "${no_issues}"
    fi
}