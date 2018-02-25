#!/bin/bash
##
# Just used for create by quilt through git .
##

function neoLog(){
    TAG=$1
    info=$2
    case ${TAG} in
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

function checkPatchName(){
    if [ "x${patchNname}" == "x" ]; then
        neoLog "ERROR" "  Please input your patch name, which as '0001-fix-hdmi-en-vdd.patch'"
        neoLog "INFO" "\t neopatch.sh <folder> <patch name>"
        exit 1
    else
        res=`expr "${patchNname}" : '[0-9]\{0,4\}-.*\.patch$'`
        if [ ${res} -lt 12 ]; then
            neoLog "ERROR" " Please input your patch name , which as '0001-fix-hdmi-en-vdd.patch'"
            neoLog "INFO" "\t neopatch.sh <folder> <patch name>"
            exit 1
        fi
    fi
}

function checkWorkPath(){
    if [ "x${workPath}" == "x" ]; then
        neoLog "ERROR" "  Please input your folder/file where you had changed. Make sure"
        neoLog "ERROR" "  the folder/file is or in a git repository."
        neoLog "INFO" "\t neopatch.sh <folder> <patch name>"
        exit 1
    fi

    if [ -f "${workPath}" ]; then
        isFile="true"
        fileName=`echo ${workPath##*/}`
        workPath=`echo ${workPath%/*}`
    fi
    if [ ! -d "${workPath}" ]; then
        neoLog "ERROR" "The folder/file $workPath isn't exist, please check."
        neoLog "ERROR" "Make sure the folder/file is or in a git repository."
        neoLog "INFO" "neopatch.sh <folder> <patch name>"
        exit 1
    else
        cd ${workPath}
        workPath=$(pwd)
        res=$(git reflog | tee /dev/null 2>&1  | wc -c)
        if [ ${res} -lt 1 ]; then
            gitPaths=`find . -type d -name "\.git" | sed "s/\.\(\/\|git\)//g;/patches/d" | uniq`
            if [ "X$gitPaths" == "X" ]; then
                neoLog "ERROR" "  The folder $workPath isn't a git repository, please check."
                neoLog "ERROR" "  Make sure the folder/file is or in a git repository."
                neoLog "INFO" "\t neopatch.sh <folder> <patch name>"
                exit 1
            fi
        else
            gitPaths=${workPath}
        fi

    fi
}

function CheckQuilt(){
    res=`expr "$(quilt --version)" : '[0-9]\+.[0-9]\+$'`
    if [ ${res} -eq 0 ]; then
        neoLog "INFO" "The program 'quilt' is currently not installed. You can install it by typing:"
        neoLog "INFO" "\tsudo apt install quilt"
        exit 1
    fi
}

function CreatePatches(){
    quilt new ${patchNname} > /dev/null 2>&1
    for gitPath in ${gitPaths}
    do
        cd ${gitPath}
        if [ "${isFile}" == "true" ]; then
            git add ${isFile} > /dev/null 2>&1
            git stash > /dev/null 2>&1
            quilt add ${isFile} > /dev/null 2>&1
            # echo -e "fileName :\n${fileName}"
        else
            modifyFiles=`git status | sed -r '/^(\w|\s+\W|\s+deleted\:)/d;/(^$|.*patch$|\.gitignore$)/d;/modified\:/!d;s/(\s|modified\:)//g'`
            deletedFiles=`git status | sed -r '/^(\w|\s+\W|\s+modified\:)/d;/(^$|.*patch$|\.gitignore$)/d;/deleted\:/!d;s/(\s|deleted\:)//g'`
            addedFiles=`git status | sed -r '/^(\w|\s+\W|\s+modified\:|\s+deleted\:)/d;/(^$|.*patch$|\.gitignore$)/d;s/\s//g;s/newfile\://g'`
            ##
            # When we add a files/directories, we should run 'git add .' then get the files name.
            ##
            if [ "x${addedFiles}" != "x" ]; then
                git add . > /dev/null 2>&1
                addedFiles=`git status | sed -r '/^(\w|\s+\W|\s+modified\:|\s+deleted\:)/d;/(^$|.*patch$|\.gitignore$)/d;s/\s//g;s/newfile\://g'`
                git stash > /dev/null 2>&1
                for addedFile in ${addedFiles}
                do
                    fileNames=`echo "${fileNames} ${addedFile}"`
                    aName=`echo ${addedFile##*/}`
                    afPath=`echo ${addedFile%/*}`
                    quilt add -P ${afPath} ${aName} > /dev/null 2>&1
                done
            fi
            if [ "x${modifyFiles}${deletedFiles}" == "x" ]; then
                git stash > /dev/null 2>&1
                for fileName in ${modifyFiles} ${deletedFiles}
                do
                    fileNames=`echo "${fileNames} ${fileName}"`
                    quilt add ${fileName} # > /dev/null 2>&1
                done
            fi

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
    quilt refresh # > /dev/null 2>&1
    # The flow cmd will remove the new changes after create patches.
    # quilt remove ${fileNames} > /dev/null 2>&1
    neoLog "SUCCEED" "Create patches succeed."
}

function GetQuiltRoot(){
    local curDir=`pwd`
    # find below at first, then find ahead.
    local qrdirs=`find . -maxdepth 5 -path "*rootfs" -prune -o -path "*u-boot" -prune -o -path "*kernel" -prune -o \
    -path "*images" -prune -o -path "*bootloader" -prune -o -path "*nvgpu" -prune -o -path "*nvmap" -prune -o \
    -path "*nvhost" -prune  -o -path "*/TX*" -prune -o -path "*display" -prune -o -path "*kernel-bak" -prune -o \
    -path "*nv_tegra" -prune -o -path "*hardware" -prune -o -path "*cuda-l4t" -prune -o -path "*cudnn" -prune -o \
    -path "*flash_tx*" -prune -o -path "*NVIDIA_CUDA-*" -prune -o -path "*PerfKit" -prune -o \
    -path "*tegra_multimedia_api" -prune -o -path "*_installer" -prune -o -path "*jetpack_docs" -prune -o \
    -path "*jetpack_download" -prune -o -path "*NVIDIA_Tegra_System_Profiler" -prune -o -path "*nvl4t_docs" -prune -o \
    -path "*tmp" -prune -o -type d -name "patches" -print | sed "s/\.\///g"`
    local qrdirN=`echo "${qrdirs}" | wc -w`
    local quiltDirN=0
    if [ ${qrdirN} -gt 1 ]; then
        for qrdir in ${qrdirs}
        do
            cd qrdir > /dev/null 2>&1
            if [ -f series ]; then
                quiltDir=$(pwd)
                ((quiltDirN=quiltDirN+1))
            fi
            cd - > /dev/null 2>&1
        done
        if [ ${quiltDirN} -eq 1 ]; then
            quiltRoot=${quiltDir}
            return
        fi
        if [ ${quiltDirN} -gt 1 ]; then
            neoLog "ERROR" "Had find ${qrdirN} patches directories,make sure which one you used."
            exit 1
        fi
    fi
    if [ ${qrdirN} -eq 1 ]; then
        quiltRoot="${curDir}/${qrdirs}"
        return
    fi

    # this is subdir so we just need find ahead.
    curDir=`echo ${curDir%/*}`
    if [ "${curDir}" == "/home/$(users)" ]; then
         neoLog "ERROR" "couldn't find patches directories,make sure you have checkout patches."
         neoLog "INFO" "git clone -b <remote branch> ssh://WeiJieYng@developer.miivii.com:29418/miivii-sw-linux/jetson/patches"
         neoLog "INFO" " \t <remote branch>  is tx1/jetpack3.1-kernel or tx1/jetpack3.1-kernel ,etc."
         exit 1
    fi
    cd ${curDir}
    GetQuiltRoot
}

function GetRootFSDir(){
    local curDir=`pwd`
    # find below at first, then find ahead.
    local dirs=`find . -maxdepth 8 -path "*/rootfs/*" -prune -o -path "*sources" -prune -o -path "*u-boot" -prune -o \
    -path "*kernel" -prune -o -path "*images" -prune -o -path "*bootloader" -prune -o -path "*nvgpu" -prune -o \
    -path "*nvmap" -prune -o -path "*nvhost" -prune  -o -path "*/TX*" -prune -o -path "*display" -prune -o \
    -path "*kernel-bak" -prune -o -path "*nv_tegra" -prune -o -path "*hardware" -prune -o -path "*cuda-l4t" -prune -o \
    -path "*cudnn" -prune -o -path "*flash_tx*" -prune -o -path "*NVIDIA_CUDA-*" -prune -o -path "*PerfKit" -prune -o \
    -path "*tegra_multimedia_api" -prune -o -path "*_installer" -prune -o -path "*jetpack_docs" -prune -o \
    -path "*jetpack_download" -prune -o -path "*NVIDIA_Tegra_System_Profiler" -prune -o -path "*nvl4t_docs" -prune -o \
    -path "*tmp" -prune -o -type d -name "rootfs" -print | sed "s/\.\///g"`
    local dirN=`echo "${dirs}" | wc -w`
    if [ ${dirN} -gt 1 ]; then
        neoLog "ERROR" "Had find multi rootfs directories,make sure which one you used."
        return
    fi
    if [ ${dirN} -eq 1 ]; then
        rootFsDir="${curDir}/${dirs}"
        return
    fi

    # this is subdir so we just need find ahead.
    curDir=`echo ${curDir%/*}`
    if [ "${curDir}" == "/home/$(users)" ]; then
         neoLog "ERROR" "couldn't find patches directories,make sure you have checkout patches."
         neoLog "INFO" "git clone -b <remote branch> ssh://WeiJieYng@developer.miivii.com:29418/miivii-sw-linux/jetson/patches"
         neoLog "INFO" " \t <remote branch>  is tx1/jetpack3.1-kernel or tx1/jetpack3.1-kernel ,etc."
         return
    fi
    cd ${curDir}
    GetRootFSDir
}

function GetRootPatchDir(){
    local curDir=`pwd`
    # find below at first, then find ahead.
    local dirs=`find . -maxdepth 8 -path "*/rootfs" -prune -o -path "*u-boot" -prune -o -path "*images" -prune -o \
     -path "*bootloader" -prune -o -path "*nvgpu" -prune -o -path "*nvmap" -prune -o -path "*nvhost" -prune  -o \
     -path "*/TX*" -prune -o -path "*display" -prune -o -path "*kernel-bak" -prune -o -path "*nv_tegra" -prune -o \
     -path "*hardware" -prune -o -path "*cuda-l4t" -prune -o -path "*cudnn" -prune -o -path "*flash_tx*" -prune -o \
     -path "*NVIDIA_CUDA-*" -prune -o -path "*PerfKit" -prune -o -path "*tegra_multimedia_api" -prune -o \
     -path "*_installer" -prune -o -path "*jetpack_docs" -prune -o -path "*jetpack_download" -prune -o \
     -path "*NVIDIA_Tegra_System_Profiler" -prune -o -path "*nvl4t_docs" -prune -o -path "*tmp" -prune -o \
     -type d -name "rootfs-patch" -print | sed "s/\.\///g"`
    local dirN=`echo "${dirs}" | wc -w`
    if [ ${dirN} -gt 1 ]; then
        neoLog "ERROR" "Had find multi directories of rootfs patches, make sure which one you used."
        exit 1
    fi
    if [ ${dirN} -eq 1 ]; then
        rootPatchDir="${curDir}/${dirs}"
        return
    fi

    # this is subdir so we just need find ahead.
    curDir=`echo ${curDir%/*}`
    if [ "${curDir}" == "/home/$(users)" ]; then
         neoLog "INFO" "There is no patches of rootfs."
         exit 1
    fi
    cd ${curDir}
    GetRootPatchDir
}

function Checkout(){
    echo ""
}

function RecoverPatches(){
    quilt push -a > /dev/null 2>&1
    GetQuiltRoot
    workPath=${quiltRoot}/..
    checkWorkPath
    commitInfo=`cat ${quiltRoot}/README.md`
    for gitP in ${gitPaths}
    do
        cd ${gitP} > /dev/null 2>&1
        git add . > /dev/null 2>&1
        git commit -m ${commitInfo} > /dev/null 2>&1
        cd - > /dev/null 2>&1
    done
    GetRootFSDir
    GetRootPatchDir
    PatchRootFsPatches
    neoLog "SUCCEED" "push patches succeed."
}

function PatchRootFsPatches(){
    if [ "X${rootPatchDir}" != "X" ]; then
        if [ "X${rootFsDir}" == "X" ]; then
            neoLog "ERROR" "couldn't find rootfs directory."
            exit 1
        fi
        sudo cp -rf ${rootPatchDir}/* ${rootFsDir}
    fi
}

function DeletePatches(){
    GetRootFSDir
    GetRootPatchDir
    DeleteRootFsPatches
    quilt pop -a  > /dev/null 2>&1
    GetQuiltRoot
    workPath=${quiltRoot}/..
    checkWorkPath
    for gitP in ${gitPaths}
    do
        cd ${gitP} > /dev/null 2>&1
        git reset --hard HEAD^ > /dev/null 2>&1
        cd - > /dev/null 2>&1
    done
    neoLog "SUCCEED" "delete patches succeed."
}

function DeleteRootFsPatches(){
    if [ "X${rootPatchDir}" != "X" ]; then
        if [ "X${rootFsDir}" == "X" ]; then
            neoLog "ERROR" "couldn't find rootfs directory."
            exit 1
        fi
        # sudo cp -rf ${rootPatchDir}/* ${rootFsDir}
    fi
}


function ShewHelpInfo(){
    neoLog "INFO" "This tools can be used to create a new patch or remove a patch."
    neoLog "INFO" "neoquilt.sh <directory/file> <patch name> To create a patch for a directory or file."
    neoLog "INFO" "neoquilt.sh -d|-f <directory/file> -p <patch name> To create a patch for a directory or file."
    neoLog "INFO" "neoquilt.sh push [-a] patch with git commit."
    neoLog "INFO" "neoquilt.sh pop [-a] delete patches."
    neoLog "INFO" "neoquilt.sh list \t To show "
    neoLog "INFO" "neoquilt.sh applied \t To show the patches has used."
    neoLog "INFO" "neoquilt.sh check \t To show there are modified before apply patches."
    neoLog "INFO" "neoquilt.sh series \t To list all patches we had create."
    neoLog "INFO" "neoquilt.sh top \t To list all patches we had create."
    neoLog "INFO" "You can use quilt to manager your patches."
    quilt --help
    # neoLog "INFO" "neoquilt.sh <cmd> [--trace] \t To list the patch we run step by step"
}

function CheckModifyInfo(){
    checkWorkPath
    for gitP in ${gitPaths}
    do
        cd ${gitP} > /dev/null 2>&1
        git diff
        cd - > /dev/null 2>&1
    done
}

function main(){
    ###
    # Var
    ##
    workPath=$1
    patchNname=$2
    isFile="false"
    gitPaths=
    fileName=
    fileNames=
    quiltRoot=
    rootFsDir=
    rootPatchDir=

    commands="add edit fork header mail patches push refresh revert setup top annotate delete files graph import new pop \
remove shell unapplied applied diff fold grep init next  previous rename series snapshot upgrade check"

    CheckQuilt
    # parse the command line first
    TGETOPT=`getopt -n "${SCRIPT_NAME}" --longoptions check:,help,files:,patches: -o ac:hf:d:p: -- "$@"`

    if [ $? != 0 ]; then
        echo "Terminating... wrong switch"
        ShewHelpInfo
        exit 1
    fi

    eval set -- "${TGETOPT}"

    echo "${SCRIPT_NAME}"

    while [ $# -gt 0 ]; do
        case "$1" in
        -a)
            isAllFiles="true"
            ;;
        -c|--check)
            workPath=$2
            CheckModifyInfo
            ;;
        -d)
            workPath="$2"
            shift
            ;;
        -f|--files)
            workPath="$2"
            shift
            ;;
        -p|--patches)
            patchNname="$2"
            shift
            ;;
        -h|--help)
            helpInfo="true"
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "Terminating... wrong switch: $@" >&2
            ShewHelpInfo
            exit 1
            ;;
        esac
        shift
    done
    shift $(($OPTIND - 1))
    command=$1
    result=`expr "${commands}" : ".*\s${command}\s.*"`
    if [ ${result} -eq 0 ];then
        if [ -d ${command} -o -f ${command} ];then
            workPath=$1
            patchNname=$2
            checkWorkPath
            checkPatchName
            CreatePatches
            exit 0
        else
            ShewHelpInfo
            exit 1
        fi
    else
        if [ "${helpInfo}" == "true" ];then
                ShewHelpInfo
                exit 1
        fi

        if [ "${isAllFiles}" == "true" ];then
            if [ "${command}" == "push" ]; then
                RecoverPatches
            else
                neoLog "ERROR" "Please check your command!"
                ShewHelpInfo
                exit 1
            fi
            if [ "${command}" == "pop" ]; then
                echo ""
            else
                neoLog "ERROR" "Please check your command!"
                ShewHelpInfo
                exit 1
            fi
        else
            if [ "${helpInfo}" == "true" ];then
                quilt ${command} -h
            else
                quilt $*
            fi
        fi
    fi

    # echo `awk 'BEGIN{print match($commands,$command)}'`
}

## run main
main $*