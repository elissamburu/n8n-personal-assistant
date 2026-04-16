#!/bin/bash
docker compose down -v
rm .env
rm -rf volumes/
rm insstaller_state.json