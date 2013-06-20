#!/usr/bin/env bash
# vi: set softtabstop=2 shiftwidth=2 expandtab :

PROVISION_DIR='/provision'

PUPPET_DIR="${PROVISION_DIR}/puppet"
PUPSTRAP_SRC="${PROVISION_DIR}/pupstrap/pupstrap.sh"

PUPPET_MODULE_PATH=$PUPPET_DIR/modules
LIBRARIAN_MODULE_PATH=$PUPPET_DIR/puppetfile-modules
PUPPET_MANIFEST_FILE=$PUPPET_DIR/manifests/main.pp
COMBINED_MODULE_PATH="${PUPPET_MODULE_PATH}:${LIBRARIAN_MODULE_PATH}"

#-------------------------------------------------------------------------------

ME=`basename $0`

showhelp () {
cat << EOF

Pupstrap - A bootstrap to get a server ready for puppet provisioning.

Usage: $ME <action> [argument]

  $ME pre  - Prestrap: Do any configuration required before bootstrapping.
  $ME boot - Bootstrap: Install and configure everything necessary for puppet provisioning

EOF

exit
}

#-------------------------------------------------------------------------------

SETCOLOR_NORMAL="echo -en \\033[0;39m"
SETCOLOR_TITLE="echo -en \\033[0;35m"
SETCOLOR_ERROR="echo -en \\033[0;31m"
SETCOLOR_BOLD="echo -en \\033[0;1m"

echo_error () {
  echo
  $SETCOLOR_ERROR
  echo '!!!!!!!!!!!'
  echo "!! ERROR !! $1"
  echo '!!!!!!!!!!!'
  echo
  $SETCOLOR_NORMAL
}

echo_finish () {
  $SETCOLOR_TITLE
  echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
  echo
  $SETCOLOR_NORMAL
}

echo_info () {
  $SETCOLOR_TITLE ; echo " * $1" ; $SETCOLOR_NORMAL
}

echo_info_detail () {
  $SETCOLOR_TITLE ; echo "   - $1" ; $SETCOLOR_NORMAL
}

echo_title () {
  echo
  $SETCOLOR_TITLE
  echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
  echo "- $1"
  echo '~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'
  $SETCOLOR_NORMAL
}

#-------------------------------------------------------------------------------

require_root () {
  if [ "$EUID" -ne "0" ]; then
    echo_error 'This command must be ran as root!'
    exit 1
  fi
}

require_ssh_agent_forward () {
  ssh-add -L >/dev/null
  if [ $? -ne 0 ]; then
    echo_error "ssh-agent forwarding doesn't seem to be working!"
    exit 1
  fi
}

#-------------------------------------------------------------------------------

add_ssh_known_hosts () {
  echo_info_detail "$1 added to known_hosts"
  ssh -o StrictHostKeyChecking=no -T $1 2>/dev/null
}


bootstrap () {
  echo_title 'Bootstrapping'

  echo_info 'Checking system...'
  require_root
  require_ssh_agent_forward

  echo_info 'Updating apt-get'
  update_apt_get

  echo_info 'Installing required packages'
  install_apt_packages git
  install_apt_packages rubygems
  install_apt_packages wget

  echo_info 'Installing Puppet & Librarian-puppet'
  install_puppet
  install_librarian_puppet

  echo_info 'Adding ssh hosts to known_hosts'
  add_ssh_known_hosts 'git@github.com'

  echo_finish
}


enable_ssh_agent_forwarding_for_sudo () {
  SSH_AUTH_SOCK_CONF='/etc/sudoers.d/ssh-auth-sock'
  touch ${SSH_AUTH_SOCK_CONF}
  chmod 440 ${SSH_AUTH_SOCK_CONF}
  echo 'Defaults env_keep += "SSH_AUTH_SOCK"' > ${SSH_AUTH_SOCK_CONF}
}


install_apt_packages () {
  echo_info_detail "$1"
  apt-get install -y "$1" >/dev/null
}


install_librarian_puppet () {
  echo_info_detail 'installing librarian-puppet'
  gem install librarian-puppet >/dev/null
}


install_puppet () {
  echo_info_detail 'adding puppetlabs repo'
  install_puppetlabs_repo_package

  echo_info_detail 'updating apt-get'
  update_apt_get

  echo_info_detail 'installing puppet'
  apt-get install -y 'puppet-common=3.1.1-1puppetlabs1' >/dev/null
}


install_puppetlabs_repo_package () {
  . /etc/lsb-release
  repo_deb_url="http://apt.puppetlabs.com/puppetlabs-release-${DISTRIB_CODENAME}.deb"
  repo_deb_path=$(mktemp)
  wget --quiet --output-document=${repo_deb_path} ${repo_deb_url} >/dev/null
  dpkg -i ${repo_deb_path} >/dev/null
  rm ${repo_deb_path}
}


install_pupstrap_commands () {
  echo_info_detail 'pupstrap'
  ln -sf ${PUPSTRAP_SRC} /usr/local/sbin/pupstrap

  echo_info_detail 'pslibrarian-puppet: Runs librarian-puppet'
  ln -sf ${PUPSTRAP_SRC} /usr/local/sbin/pslibrarian-puppet

  echo_info_detail 'pspuppet: Runs puppet'
  ln -sf ${PUPSTRAP_SRC} /usr/local/sbin/pspuppet
}


prestrap () {
  echo_title 'Pre-strapping'

  echo_info 'Checking system...'
  require_root

  echo_info 'Setup ssh'
  setup_ssh

  echo_info 'Install pupstrap commands'
  install_pupstrap_commands

  echo_finish
}


run_librarian_puppet () {
  echo_title 'Running librarian-puppet'
  require_root

  if [ ! -d "$LIBRARIAN_MODULE_PATH" ]; then
    run_librarian_puppet_install
  else
    run_librarian_puppet_update
  fi
}


run_librarian_puppet_cmd () {
  run_cmd="librarian-puppet $1 --verbose"
  echo_info_detail "$run_cmd"
  (cd $PUPPET_DIR && $run_cmd)
}

run_librarian_puppet_install () {
  echo_info 'Installing librarian-puppet modules'
  run_librarian_puppet_cmd "install --clean --path=$LIBRARIAN_MODULE_PATH"
}


run_librarian_puppet_update () {
  echo_info 'Updating librarian-puppet modules'
  run_librarian_puppet_cmd 'update'
}


run_puppet () {
  echo_title 'Running puppet'
  require_root
  (puppet apply -vv --modulepath=$COMBINED_MODULE_PATH $PUPPET_MANIFEST_FILE)
}


setup_ssh () {
  echo_info_detail 'enable ssh-agent forwarding to sudo'
  enable_ssh_agent_forwarding_for_sudo
}


update_apt_get () {
  apt-get update >/dev/null
}

#-------------------------------------------------------------------------------

while [ $# -gt 0 ]; do
  case "$1" in
    pre)
      action=prestrap
      shift
      ;;
    boot)
      action=bootstrap
      shift
      ;;
    libpup)
      action=libpup
      shift
      ;;
    puppet)
      action=puppet
      shift
      ;;
    *)
      showhelp
      ;;
  esac
done


case "$ME" in
  pslibrarian-puppet)
    action=libpup
    ;;
  pspuppet)
    action=puppet
    ;;
esac


case $action in 
  prestrap) prestrap ;;
  bootstrap) bootstrap ;;
  libpup) run_librarian_puppet ;;
  puppet) run_puppet ;;
  * ) showhelp ;;
esac
