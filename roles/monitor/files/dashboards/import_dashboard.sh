#!/bin/sh
#
# add the "-x" option to the shebang line if you want a more verbose output
#
#
OPTSPEC=":hp:t:k:"

show_help() {
cat << EOF
Usage: $0 [-p PATH] [-t TARGET_HOST] [-k API_KEY]
Script to import dashboards into Grafana
    -p      Required. Root path containing JSON exports of the dashboards you want imported.
    -t      Required. The full URL of the target host
    -k      Required. The API key to use on the target host

    -h      Display this help and exit.
EOF
}

###### Check script invocation options ######
while getopts "$OPTSPEC" optchar; do
    case "$optchar" in
        h)
            show_help
            exit
            ;;
        p)
            DASH_DIR="$OPTARG";;
        t)
            HOST="$OPTARG";;
        k)
            KEY="$OPTARG";;
        \?)
          echo "Invalid option: -$OPTARG" >&2
          exit 1
          ;;
        :)
          echo "Option -$OPTARG requires an argument." >&2
          exit 1
          ;;
    esac
done

if [ -z "$DASH_DIR" ] || [ -z "$HOST" ] || [ -z "$KEY" ]; then
    show_help
    exit 1
fi

# set some colors for status OK, FAIL and titles
SETCOLOR_SUCCESS="echo -en \\033[0;32m"
SETCOLOR_FAILURE="echo -en \\033[1;31m"
SETCOLOR_NORMAL="echo -en \\033[0;39m"
SETCOLOR_TITLE_PURPLE="echo -en \\033[0;35m" # purple

# usage log "string to log" "color option"
function log_success() {
   if [ $# -lt 1 ]; then
       ${SETCOLOR_FAILURE}
       echo "Not enough arguments for log function! Expecting 1 argument got $#"
       exit 1
   fi

   timestamp=$(date "+%Y-%m-%d %H:%M:%S %Z")

   ${SETCOLOR_SUCCESS}
   printf "[%s] $1\n" "$timestamp"
   ${SETCOLOR_NORMAL}
}

function log_failure() {
   if [ $# -lt 1 ]; then
       ${SETCOLOR_FAILURE}
       echo "Not enough arguments for log function! Expecting 1 argument got $#"
       exit 1
   fi

   timestamp=$(date "+%Y-%m-%d %H:%M:%S %Z")

   ${SETCOLOR_FAILURE}
   printf "[%s] $1\n" "$timestamp"
   ${SETCOLOR_NORMAL}
}

function log_title() {
   if [ $# -lt 1 ]; then
       ${SETCOLOR_FAILURE}
       log_failure "Not enough arguments for log function! Expecting 1 argument got $#"
       exit 1
   fi

   ${SETCOLOR_TITLE_PURPLE}
   printf "|-------------------------------------------------------------------------|\n"
   printf "|%s|\n" "$1";
   printf "|-------------------------------------------------------------------------|\n"
   ${SETCOLOR_NORMAL}
}

if [ -d "$DASH_DIR" ]; then
    DASH_LIST=$(find "$DASH_DIR" -mindepth 1 -name \*.json)
    if [ -z "$DASH_LIST" ]; then
        log_title "----------------- $DASH_DIR contains no JSON files! -----------------"
        log_failure "Directory $DASH_DIR does not appear to contain any JSON files for import. Check your path and try again."
        exit 1
    else
        FILESTOTAL=$(echo "$DASH_LIST" | wc -l)
        log_title "----------------- Starting import of $FILESTOTAL dashboards -----------------"
    fi
else
    log_title "----------------- $DASH_DIR directory not found! -----------------"
    log_failure "Directory $DASH_DIR does not exist. Check your path and try again."
    exit 1
fi

NUMSUCCESS=0
NUMFAILURE=0
COUNTER=0

for DASH_FILE in $DASH_LIST; do
    COUNTER=$((COUNTER + 1))
    echo "Import $COUNTER/$FILESTOTAL: $DASH_FILE..."
    RESULT=$(cat "$DASH_FILE" | jq '. * {overwrite: true, dashboard: {id: null}}' | curl -s -X POST -H "Content-Type: application/json" -H "Authorization: Bearer $KEY" "$HOST"/api/dashboards/db -d @-)
    if [[ "$RESULT" == *"success"* ]]; then
        log_success "$RESULT"
        NUMSUCCESS=$((NUMSUCCESS + 1))
    else
        log_failure "$RESULT"
        NUMFAILURE=$((NUMFAILURE + 1))
    fi
done

log_title "Import complete. $NUMSUCCESS dashboards were successfully imported. $NUMFAILURE dashboard imports failed.";
log_title "------------------------------ FINISHED ---------------------------------";


######################## create api key 
##  curl -X POST -H "Content-Type: application/json" -d '{"name":"apikeycurl", "role": "Admin", ""}' http://admin:admin@10.10.2.13:3000/api/auth/keys
##  
######################## delete api key 
##  curl -X DELETE -H "Content-Type: application/json" http://admin:admin@10.10.2.13:3000/api/auth/keys/:id
##
########################