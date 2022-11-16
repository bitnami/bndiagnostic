#!/bin/bash
function checkResources {
    local partition=$(df -P /opt/bitnami | tail -1 | cut -d' ' -f 1)
    local diskspace=$(df -h "${partition}" | grep -v boot | awk '{print $5}'| tail -1 | sed 's/%/ /g' 2> /dev/null)
    local diskspace_example=$(format "wrap" "$(df -h "${partition}" | sed 's/%/%%/g')")
    if [[ $(wc -l < /proc/swaps) > 1 ]]; then
        swap_enabled=true
    fi
    if [ "$diskspace" -gt 80 ]; then
        no_issues=false
        format "suggest" "Your disk is almost full: You could try to increase your instance's storage.${diskspace_example}Please check your cloud provider's documentation for more information."
    fi
    local memory_example="$(free -m)"
    local free_memory_percentage=$(LC_ALL="C" LANG="C" free | grep -i mem | awk '{print int($4/$2 * 100.0)}')
    if [ "$free_memory_percentage" -lt 20 ]; then
        no_issues=false
        format "suggest" "Your instance has little available RAM memory.$(format "wrap" "${memory_example}")You could try to increase your instance's memory. Please check your cloud provider's documentation for more information."
        if [ ! $swap_enabled ]; then
            format "suggest" "You can also enable swap memory to improve performance."
            format "link" "https://docs.bitnami.com/installer/faq/linux-faq/administration/increase-memory-linux/"
        fi
    else
        if [ $swap_enabled ]; then
            free_swap_percentage=$(LC_ALL="C" LANG="C" free | grep -i swap | awk '{print int($4/$2 * 100.0)}')
            if [ "$free_swap_percentage" -lt 90 ] && [ "$free_memory_percentage" -lt 40 ]; then
                format "suggest" "Your instance is using swap memory:${memory_example}This usually means that your instance is running low on memory. You could try to increase your instance's memory. Please check your cloud provider's documentation for more information."
            fi
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
    checkResources
    addStatus "${component^}" "$no_issues"
    if $no_issues; then
        format "clear" "${no_issues}"
    fi
}