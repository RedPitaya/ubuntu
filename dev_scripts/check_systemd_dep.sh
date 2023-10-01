#!/bin/bash

systemd-analyze dot --no-pager --order | python dot_find_cycles.py

