#!/bin/bash
# =============================================================================
# config.sh — Global configuration for Scenario 8 (1 CU, 1 DU, 1 cell, USRP B210)
#
# Single-cell deployment using real RF via USRP B210 (USB 3.0).
# OSC Near-RT RIC for E2SM-KPM monitoring.
# =============================================================================

# RIC choice
export RIC_CHOICE="${RIC_CHOICE:-osc}"

# --- USRP B210 Configuration ---
# Serial number of your B210 (run 'uhd_find_devices' to discover).
# Leave empty to auto-detect (works if only one USRP is connected).
#export USRP_SERIAL="${USRP_SERIAL:-}"
export USRP_SERIAL="34C78F0"

# RF gains (adjust for your environment; B210 range: 0–89.8 dB)
export USRP_TX_GAIN="${USRP_TX_GAIN:-70}"
export USRP_RX_GAIN="${USRP_RX_GAIN:-70}"
