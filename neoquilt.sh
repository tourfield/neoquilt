#!/bin/bash
##
# Just used for create by quilt through git .
##

workPath=$1
patchNname=$2
isFile="false"
gitPaths=
fileName=
fileNames=

function neoLog(){
    TAG=$1
    info=$2
    case $TAG in
    "INFO")
        echo -e "\033[33m$info\033[0m"
        ;;
    "ERROR")
        echo -e "\033[31m$info\033[0m"
        ;;
    "DEBUG")
        echo -e "\033[34m$info\033[0m"
        ;;
    "SUCCEED")
        echo -e "\033[32m$info\033[0m"
        ;;
    *)
        echo "$info"
        ;;
    esac
}

function checkArgvs(){
    if [ "x$workPath" == "x" ]; then
        neoLog "ERROR" "  Please input your folder/file where you had changed. Make sure"
        neoLog "ERROR" "  the folder/file is or in a git repository."
        neoLog "INFO" "\t neopatch.sh <folder> <patch name>"
        exit 1
    fi

    if [ "x$patchNname" == "x" ]; then
        neoLog "ERROR" "  Please input your patch name, which as '0001-fix-hdmi-en-vdd.patch'"
        neoLog "INFO" "\t neopatch.sh <folder> <patch name>"
        exit 1
    else
        res=`expr "$patchNname" : '[0-9]\{0,4\}-.*\.patch$'`
        if [ $res -lt 12 ]; then
            neoLog "ERROR" " Please input your patch name , which as '0001-fix-hdmi-en-vdd.patch'"
            neoLog "INFO" "\t neopatch.sh <folder> <patch name>"
            exit 1
        fi
    fi

    if [ -f "$workPath" ]; then
        isFile="true"
        fileName=`echo ${workPath##*/}`
        workPath=`echo ${workPath%/*}`
    fi
    if [ ! -d "$workPath" ]; then
        neoLog "ERROR" "The folder/file $workPath isn't exist, please check."
        neoLog "ERROR" "Make sure the folder/file is or in a git repository."
        neoLog "INFO" "neopatch.sh <folder> <patch name>"
        exit 1
    else
        cd $workPath
        workPath=$(pwd)
        res=$(git reflog | tee /dev/null 2>&1  | wc -c)
        gitPaths=`find . -type d -name "\.git" | sed "s/\.\(\/\|git\)//g" | uniq`
        if [ $res -lt 1 ]; then
            if [ "X$gitPaths" == "X" ]; then
                neoLog "ERROR" "  The folder $workPath isn't a git repository, please check."
                neoLog "ERROR" "  Make sure the folder/file is or in a git repository."
                neoLog "INFO" "\t neopatch.sh <folder> <patch name>"
                exit 1
            fi
        else
            gitPaths=$workPath
        fi

    fi
}

function checkQuilt(){
    res=`expr "$(quilt --version)" : '[0-9]\+.[0-9]\+$'`
    if [ $res -eq 0 ]; then
        neoLog "INFO" "The program 'quilt' is currently not installed. You can install it by typing:"
        neoLog "INFO" "\tsudo apt install quilt"
        exit 1
    fi
}

function createPatches(){
    quilt new ${patchNname} > /dev/null 2>&1
    for gitPath in $gitPaths
    do
        cd $gitPath
        if [ "${isFile}" == "true" ]; then
            git add ${isFile} > /dev/null 2>&1
            git stash > /dev/null 2>&1
            quilt add ${isFile} > /dev/null 2>&1
            # echo -e "fileName :\n${fileName}"
        else
            modifyFiles=`git status | sed -r '/^(\w|\s+\W|\s+deleted\:)/d;/(^$|.*patch$|\.gitignore$)/d;/modified\:/!d;s/(\s|modified\:)//g'`
            deletedFiles=`git status | sed -r '/^(\w|\s+\W|\s+modified\:)/d;/(^$|.*patch$|\.gitignore$)/d;/deleted\:/!d;s/(\s|deleted\:)//g'`
            addedFiles=`git status | sed -r '/^(\w|\s+\W|\s+modified\:|\s+deleted\:)/d;/(^$|.*patch$|\.gitignore$)/d;s/\s//g'`
            if [ "x${addedFiles}" != "x" ]; then
                for addedFile in ${addedFiles}
                do
                    fileNames=`echo "${fileNames} ${addedFile}"`
                    git add ${addedFile} > /dev/null 2>&1
                done
            fi
            git stash > /dev/null 2>&1
            for fileName in ${modifyFiles} ${deletedFiles}
            do
                fileNames=`echo "${fileNames} ${fileName}"`
                quilt add ${fileName} > /dev/null 2>&1
            done
            # quilt files
            # echo -e "modifyFiles :\n${modifyFiles}"
            # echo -e "deletedFiles :\n${deletedFiles}"
            # echo -e "addedFiles :\n${addedFiles}"
        fi
        git stash pop > /dev/null 2>&1
        if [ "x${addedFiles}" != "x" ]; then
            git reset > /dev/null 2>&1
        fi
        cd - > /dev/null
    done
    quilt refresh > /dev/null 2>&1
    # The flow cmd will remove the new changes after create patches.
    # quilt remove ${fileNames} > /dev/null 2>&1
    neoLog "SUCCEED" "Create patches succeed."
}

function main(){
    checkQuilt
    checkArgvs
    createPatches
}

## run main
main