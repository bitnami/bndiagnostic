#!/bin/bash

set -o pipefail;
secureOutput=0;
BND_DIR="$(cd "$( dirname  "$(realpath "${BASH_SOURCE[0]}")")" >/dev/null && pwd)"
source "${BND_DIR}/bndiagnostic-common-lib.sh"

checkValidInstallDir

if [[ $(whoami) != "root" ]]; then
    echo "Please run the tool with sudo"
    echo ""
    echo "    sudo $0"
    echo ""
    exit 0
fi
OPTS=`getopt -o hlso: --long help,list-components,secure-output,output-directory: -n 'parse-options' -- "$@"`
if [ $? != 0 ] ; then showHelp; >&2 ; exit 1 ; fi
eval set -- "$OPTS"
while true; do
  case "$1" in
    -h | --help ) showHelp;
    ;;
    -l | --list-components ) showOptions;
    ;;
    -s | --secure-output ) secureOutput=1; shift;
    ;;
    -o | --output-directory ) outputDirectory=$2; shift 2;
    ;;
    --) shift; break;
    ;;
  esac
done

checkComponents

if [[ ! $stat =~ "possible issues" ]]; then
    format "suggest" "The diagnostic tool couldn't find any issues."
fi

printf -v status "${stat}"
printf -v details "${suggest}"

echo " ${status} "
echo ""
echo " ${details} "


if [ -d "$outputDirectory" ]; then
  cat << EOF > $outputDirectory/bndiagnostic_output
${status}

${details}

EOF

  if [ -f $outputDirectory/bndiagnostic_simple_output ]; then
    rm $outputDirectory/bndiagnostic_simple_output
  fi
  if [[ $stat =~ "possible issues" ]]; then
    while read line; do
      if [[ "$line" =~ "Found possible issues" ]]; then
        echo "$line" >> $outputDirectory/bndiagnostic_simple_output
      elif [[ "$line" =~ "docs.bitnami.com" ]]; then
        echo "$line" >> $outputDirectory/bndiagnostic_simple_output
      fi
    done < $outputDirectory/bndiagnostic_output
  else
    echo "The diagnostic tool couldn't find any issues." >> $outputDirectory/bndiagnostic_simple_output
  fi
fi
