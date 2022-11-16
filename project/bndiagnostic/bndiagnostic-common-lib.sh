#!/bin/bash

stat="\n";
suggest="";
black="\033[01;30m";
red="\033[0;31m";
cyan="\033[0;36m";
reset="\033[0m";
green="\033[0;32m";
yellow="\033[01;33m";

###Functions
function showHelp {
    echo ""
    echo "Usage:"
    echo " $0    :Perform a check on all available components"
    echo " $0 [ -h | --help ] :Display this help menu"
    echo " $0 [ -s | --secure-output ] :Secure output"
    echo " $0 [ -l | --list-components ] :Show the list of components that will be checked"
    echo ""
    exit 0
}

function getComponents {
    local component_list="";
    for component_file in $(find "${BND_DIR}/components" -type f); do
        . "${component_file}";
        if [[ "$(validate)" -eq "1" ]]; then
            component_list="${component_list}$(echo "${component_file}" | sed -n 's/.*-\(.*\).sh$/\1/p') ";
        fi
    done
    echo "${component_list}";
}

function is_boolean_yes() {
    local -r bool="${1:-}"
    # comparison is performed without regard to the case of alphabetic characters
    shopt -s nocasematch
    if [[ "$bool" = 1 || "$bool" =~ ^(yes|true)$ ]]; then
        true
    else
        false
    fi
}

function obfuscate() {
    local outputFile="$1"
    if is_boolean_yes "$secureOutput"; then
        cat "$outputFile" | sed -r 's/(\b[0-9]{1,3}\.){3}[0-9]{1,3}\b/**ip_address**/'
    else
        cat "$outputFile"
    fi
}

function filterLog () {
    local file="$1"
    local regex="$2"
    local lines="$3"
    local filter="$4"
    local truncateChars="1-500"
    local tempOutput="/tmp/logOutput_${RANDOM}"
    if [ ! -z "$filter" ]; then
        tail -n 50 ${file} | grep -iE "${regex}" | grep -iEv "${filter}" | tail -n $lines | sed 's/$/\\n/g' | sed 's/%/%%/g' | cut --characters="$truncateChars" > "$tempOutput"
    else
        tail -n 50 ${file} | grep -iE "${regex}" | tail -n $lines | sed 's/$/\\n/g' | sed 's/%/%%/g' | cut --characters="$truncateChars" > "$tempOutput"
    fi
    if [ -f "$tempOutput" ]; then
        obfuscate "$tempOutput"
        rm -f "$tempOutput"
    fi
}

function showOptions {
    local component_list;
    component_list="$(getComponents)";
    echo "";
    echo "Components that will be checked:";
    echo "";
    echo "${component_list// /,}";
    echo "";
    exit 0;
}

function checkComponents {
    local component_list;
    component_list=$(getComponents);
    for component in ${component_list}; do
        . "${BND_DIR}/components/bndiagnostic-${component}.sh";
        run;
    done
}

function checkValidInstallDir {
    install_dir="/opt/bitnami";
    if [ ! -d "${install_dir}/" ]; then
        echo "No valid installation directory has been found in \"/opt/bitnami\"";
        exit 1;
    fi
}

function addStatus {
    if $2; then
        stat="${stat}    ${green}\xE2\x9C\x93$reset $1: No issues found\n";
    else
        stat="${stat}    $yellow?$reset $1: Found possible issues\n";
    fi
}

function format {
    local mode="$1";
    shift;
    local text="$*";
    local end="${reset}\n";
    local newline="\n";
    local link_start="\n${cyan}";
    local code_start="\n    \$ ${cyan}";
    local comp;
    if [ ! -z "${current_component}" ]; then
        comp="${yellow}${current_component})${reset} ";
    else
        comp="";
    fi
    local wrap_start="\n${black}\`\`\`${red}\n";
    local wrap_end="\n${black}\`\`\`${reset}\n";
    if [[ ! -z "$text" ]]; then
        case $mode in
            suggest )
                suggest="${suggest}${newline}${comp}${text}${newline}";
            ;;
            wrap )
                echo "${wrap_start}${text}${wrap_end}";
            ;;
            section )
                suggest="${suggest}${yellow}${newline}[${component^}]${newline}${reset}";
            ;;
            clear )
                suggest=$(echo ${suggest} | sed "s/\\\n\[${component^}\]\\\n//g")
            ;;
            path )
                echo "${cyan}${text}${reset}";
            ;;
            code )
                suggest="${suggest} ${code_start}${text}${end}";
            ;;
            link )
                suggest="${suggest} ${link_start}${text}${end}";
            ;;
        esac
    fi
}
