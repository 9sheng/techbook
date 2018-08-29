# ubnutu开发环境搭建

```sh
#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

# ==== add priv to vbox share ====
sudo usermod -a -G vboxsf $(whoami)

# ==== install softwares ====
sudo apt-add-repository ppa:ubuntu-elisp/ppa   # for emacs
sudo apt-add-repository ppa:fcitx-team/nightly # for sogou-input
sudo apt-get update
sudo apt-get upgrade -y

PKG_TO_INSTALL=(build-essential cgdb cmake curl emacs fcitx git golang-go htop ipython kcachegrind kdiff3 subversion terminator tmux vim zsh)
for pkg in ${PKG_TO_INSTALL[@]}; do
  echo sudo apt-get install -y $pkg
done

# ==== config git ====
git config --global color.status auto
git config --global color.diff auto
git config --global color.branch auto
git config --global color.interactive auto
git config --global user.email "liulin59@gmail.com"
git config --global user.name "9sheng"

# ==== config emacs ====
rm -rf ~/.emacs.d ~/.spacemacs.d
git clone https://github.com/9sheng/spacemacs.git ~/.emacs.d
git clone https://github.com/9sheng/spacemacs-private.git ~/.spacemacs.d
(cd ~/.spacemacs.d && git checkout -b 9sheng remotes/origin/9sheng)

# ==== config vim ====
cat <<EOF > ~/.vimrc
set ts=4
set noexpandtab
set sw=4
set nu
set ic
set nobackup
EOF

# ==== config zsh ====
git clone http://gitlab.biztech.sogou-inc.com/liulin209544/toolkit.git ~/toolkit
sh -c "$(curl -fsSL https://raw.github.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"

cat <<EOF >> ~/.zshrc
export GOPATH=~/workspace/golang
export PATH=$PATH:~/toolkit/bin:$GOPATH/bin
EOF

chsh -s $(which zsh)

# ==== config svn ====
sed -i -e 's/# merge-tool-cmd =.*/merge-tool-cmd = svn-kdiff3-merge.sh/' -e 's/# diff-cmd =.*/diff-cmd = svn-kdiff3.sh/' ~/.subversion/config

# ==== install go tools ====
go install github.com/rogpeppe/godef

# ==== end of file ====
# 安装中文支持
# 输入法后续调整搜狗输入法为默认
# 对某个工程设置
# git config --local user.email "liulin209544@sogou-inc.com"
# git config --local user.name "liulin"
```

## network setting
iwlwifi 驱动不支持802.11n 协议, 所以如果路由器要是使用这个协议的话无线上网就表现为已经连上了可没有速度。按照网上找到的方法，直接禁用掉802.11n协议，但是速度会被限制在54Mb/s

```sh
echo "options iwlwifi 11n_disable=1" >> /etc/modprobe.d/iwlwifi.conf
```

## apt-get proxy
use environment variables, do NOT work.
```sh
export http_proxy=http://yourproxyaddress:proxyport
export https_proxy=http://yourproxyaddress:proxyport
```
modify file /etc/apt/apt.conf, add the following:
```
Acquire::http::Proxy "http://yourproxyaddress:proxyport"
```
## squid代理服务器
安装完后需要设置localnet localhost相关配置
