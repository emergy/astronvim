ARG BASE_IMAGE=ubuntu:24.04
FROM ${BASE_IMAGE}
USER root
ENV HOME=/root
COPY . /tmp/astronvim-feature
# Smoke checks intentionally do not bootstrap Lazy, Mason, or parsers.
ENV INSTALLPLUGINS=false
RUN bash /tmp/astronvim-feature/install.sh
RUN useradd -m -s /bin/bash featureuser
USER featureuser
ENV HOME=/home/featureuser
WORKDIR /home/featureuser
CMD ["/bin/bash", "-euc", "astronvim-setup; printf '\\n-- user edit\\n' >> \"$HOME/.config/nvim/init.lua\"; astronvim-setup; test -w \"$HOME/.cache/nvim\"; test -w \"$HOME/.local/share/nvim\"; grep -q -- '-- user edit' \"$HOME/.config/nvim/init.lua\"; nvim --headless -u NONE -i NONE -c 'lua assert(vim.fn.has(\"nvim-0.11\") == 1)' -c qa; astronvim-python -c 'import pynvim'; ansible-vault --version; node --version; tree-sitter --version; fd --version; rg --version; lazygit --version"]
