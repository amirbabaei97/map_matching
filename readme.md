# Map Matching with Valhalla

This repository provides an intuitive guideline to map-match GPS trajectories to the underlying OpenStreetMap (OSM) map using the Valhalla engine with the help of Apache Spark.

## Overview

The map-matching process involves:
1. Running the Valhalla engine on an Ubuntu system.
2. Filtering and preparing GPS trajectory data.
3. Map-matching the points to the OSM way_ids.

## Files and Scripts

- **`build_valhalla.sh`**: A shell script to set up and run the Valhalla engine on an Ubuntu system on port 8002(Valhalla default port).
- **`filtering.ipynb`**: A Jupyter notebook for filtering and preparing GPS trajectory data.
- **`map-matching.ipynb`**: A Jupyter notebook for map-matching the filtered trajectories.

## Data Source

The GPS trajectory data is provided by Inrix for the project **DZwEI**.

## Usage

1. Run `build_valhalla.sh` to set up the Valhalla routing engine(and map-matching API).
2. Use `filtering.ipynb` to preprocess the GPS trajectory data.
3. Execute `map-matching.ipynb` to map-match the trajectories to the OSM map.

## Requirements

- Ubuntu system
- Valhalla engine
- Jupyter Notebook
