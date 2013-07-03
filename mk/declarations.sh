# Copyright (c) Citrix Systems Inc. 
# All rights reserved.
# 
# Redistribution and use in source and binary forms, 
# with or without modification, are permitted provided 
# that the following conditions are met: 
# 
# *   Redistributions of source code must retain the above 
#     copyright notice, this list of conditions and the 
#     following disclaimer. 
# *   Redistributions in binary form must reproduce the above 
#     copyright notice, this list of conditions and the 
#     following disclaimer in the documentation and/or other 
#     materials provided with the distribution. 
# 
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND 
# CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, 
# INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
# MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE 
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR 
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
# SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
# BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR 
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, 
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
# NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE 
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF 
# SUCH DAMAGE.

#==============================================================
#Micro version override - please keep at the top of the script
#==============================================================
#Set and uncomment this to override the 3rd value of the product number 
#normally fetched from branding
#
#PRODUCT_MICRO_VERSION_OVERRIDE=<My override value here>

#this is the XenServer branch we're building; change this when making a new branch

if [ -n "${DEBUG+xxx}" ]; 
then 
	set -x
fi

# that's the code to get the branch name of the repository
SOURCE="${BASH_SOURCE[0]}"
DIR="$( dirname "$SOURCE" )"
pushd $PWD
while [ -h "$SOURCE" ]
do 
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
  DIR="$( cd -P "$( dirname "$SOURCE"  )" && pwd )"
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
popd

if [ -z "${JOB_NAME+xxx}" ]
then 
    JOB_NAME="devbuild"
    echo "Warning: JOB_NAME env var not set, we will use ${JOB_NAME}"
fi

if [ -z "${BUILD_NUMBER+xxx}" ]
then 
    BUILD_NUMBER="0"
    echo "Warning: BUILD_NUMBER env var not set, we will use ${BUILD_NUMBER}"
fi

if [ -z "${BUILD_ID+xxx}" ]
then 
    BUILD_ID=$(date +"%Y-%m-%d_%H-%M-%S")
    echo "Warning: BUILD_ID env var not set, we will use ${BUILD_ID}"
fi

if [ -z "${BUILD_URL+xxx}" ]
then 
    BUILD_URL="n/a"
    echo "Warning: BUILD_URL env var not set, we will use 'n/a'"
fi


if [ -z "${GIT_COMMIT+xxx}" ]
then 
    GIT_COMMIT="none"
    echo "Warning: GIT_COMMENT env var not set, we will use 'none'"
fi

get_GIT_REVISION="${GIT_COMMIT}"

if [ -z "${get_GIT_REVISION+xxx}" ]
then 
    get_GIT_REVISION="none"
    echo "Warning: GIT_COMMIT env var not set, we will use $get_GIT_REVISION"
fi

pwd
BRANCH=`git --git-dir="$REPO/.git" rev-parse --abbrev-ref HEAD`

[ -z "$BRANCH" ] && echo "Unable to detect branch name" && exit 1;

if [ "$BRANCH" = "master" ]
then
    XS_BRANCH="trunk"
else
    XS_BRANCH=`cd $DIR;git config --get remote.origin.url|sed -e 's@.*carbon/\(.*\)/xenadmin.git.*@\1@'`
    [ -z "$XS_BRANCH" ] && echo "Unable to detect branch name, git returned: " `cd $DIR;git config --get remote.origin.url` && exit 1;
fi


echo "Running on branch: ${XS_BRANCH} (${BRANCH})"

cd ${ROOT_DIR}
if [ -d "xenadmin-ref.hg" ]
then
  hg --cwd xenadmin-ref.hg pull -u
else
  hg clone ssh://xenhg@hg.uk.xensource.com/carbon/${XS_BRANCH}/xenadmin-ref.hg/
fi

#rename Jenkins environment variables to distinguish them from ours; remember to use them as get only
get_JOB_NAME=${JOB_NAME}
get_BUILD_NUMBER=${BUILD_NUMBER}
get_BUILD_ID=${BUILD_ID}
get_BUILD_URL=${BUILD_URL}

#do everything in place as jenkins runs a clean build, i.e. will delete previous artifacts on starting
if [ -z "${WORKSPACE+xxx}" ]
then 
    WORKSPACE="$( cd "$DIR/../.." && pwd )"
    echo "Warning: WORKSPACE env var not set, we will use '${WORKSPACE}'"
fi

if which cygpath >/dev/null; then
    ROOT=$(cygpath -u "${WORKSPACE}")
else
    ROOT=${WORKSPACE}
fi

echo "Workspace located in: $ROOT"
REPO=${ROOT}/xenadmin.git
REF_REPO=${ROOT}/xenadmin-ref.hg
SCRATCH_DIR=${ROOT}/scratch
OUTPUT_DIR=${ROOT}/output
TEST_DIR=/cygdrive/c/cygwin/tmp
BUILD_ARCHIVE=${ROOT}/../builds/${get_BUILD_ID}/archive
#XENCENTER_LOGDIR="/cygdrive/c/Users/Administrator/AppData/Roaming/Citrix/XenCenter/logs"
XENCENTER_LOGDIR="/cygdrive/c/Citrix/XenCenter/logs"

#this is where the libraries stored in /usr/groups/linux/distfiles are exposed
WEB_LIB="http://files.uk.xensource.com/linux/distfiles/windows-build"

#this is where the current build will retrieve some of its dependendencies,
#i.e. XenCenterOvf, version number, branding info and XenServer.NET;
#use xe-phase-2-latest to ensure we use a build where phases 1 and 2 have succeeded
WEB_LATEST_BUILD="http://www.uk.xensource.com/carbon/${XS_BRANCH}/xe-phase-2-latest"
WEB_XE_PHASE_1=${WEB_LATEST_BUILD}/xe-phase-1
WEB_XE_PHASE_2=${WEB_LATEST_BUILD}/xe-phase-2

#this is where the build will find stuff from the latest dotnet-packages build
WEB_DOTNET="http://localhost:8080/job/carbon_${XS_BRANCH}_dotnet-packages/lastSuccessfulBuild/artifact"

#check there are xenserver builds on this branch before proceeding
wget -N -q --spider ${WEB_XE_PHASE_1}/globals || { echo 'FATAL: Unable to locate globals, xenadmin cannot be built if there is no succesfull build of xenserver published for the same branch.' ; exit 1; }

