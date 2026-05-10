# All five synthetic providers in this reference framework are configuration-free:
# null, random, local, time, and tls. Source and version pins live in versions.tf;
# no provider blocks are needed.
#
# This is intentional for module hygiene: empty provider blocks are deprecated
# when this framework is consumed as a child module by runner integration.
