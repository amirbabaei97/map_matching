#!/bin/bash
set -e  # Stop on first error

echo "🛠️ [Step 1] Updating System & Installing Dependencies..."
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=l
apt update && apt upgrade -yq

apt install -y \
  build-essential cmake make g++ jq curl unzip wget git \
  libboost-all-dev libsqlite3-dev liblz4-dev \
  libprotobuf-dev protobuf-compiler \
  zlib1g-dev libzmq3-dev python3 python3-pip \
  autoconf automake pkg-config libtool lcov libcurl4-openssl-dev \
  libczmq-dev autoconf-archive libluajit-5.1-dev libspatialite-dev

echo "✅ System updated and dependencies installed."

# ----------------------------------------------------------------

echo "🛠️ [Step 2] Installing Prime Server..."
cd /opt

# Clone only if it doesn't already exist
if [ ! -d "prime_server" ]; then
  git clone --recurse-submodules https://github.com/kevinkreiser/prime_server.git
else
  echo "✅ Prime Server directory already exists, pulling latest updates..."
  cd prime_server
  git reset --hard
  git pull --recurse-submodules
fi


cd prime_server

echo "🔄 Updating submodules..."
git submodule update --init --recursive

echo "🔧 Ensuring execute permissions on autogen.sh..."
chmod +x autogen.sh

echo "⚙️ Running Build Steps..."
./autogen.sh
./configure
make -j$(nproc)
make install
ldconfig

echo "✅ Prime Server installed successfully."

# ----------------------------------------------------------------

echo "🛠️ [Step 3] Cloning and Building Valhalla..."
cd /opt
if [ ! -d "valhalla" ]; then
  git clone --recurse-submodules https://github.com/valhalla/valhalla.git
fi

cd valhalla
echo "🔄 Updating Valhalla repo..."
git reset --hard
git pull --recurse-submodules
git submodule update --init --recursive

echo "📁 Creating build directory..."
mkdir -p build && cd build

echo "⚙️ Running CMake configuration..."
cmake .. -DCMAKE_BUILD_TYPE=Release -DENABLE_SERVICES=ON -DENABLE_HTTP=ON

echo "🔨 Building Valhalla (this may take a while)..."
make -j$(nproc)

echo "🚀 Installing Valhalla..."
make install

echo "✅ Valhalla built and installed."

# ----------------------------------------------------------------

echo "🗺️ [Step 4] Downloading Hessen OSM Extract..."
mkdir -p /data/valhalla
cd /data/valhalla

wget -O hessen-latest.osm.pbf http://download.geofabrik.de/europe/germany/hessen-latest.osm.pbf
echo "✅ Hessen OSM extract downloaded."

# ----------------------------------------------------------------

echo "🛠️ [Step 5] Generating Valhalla Configuration..."
valhalla_build_config \
  --mjolnir-tile-dir /data/valhalla/tiles \
  --mjolnir-tile-extract /data/valhalla/valhalla_tiles.tar \
  --mjolnir-timezone /data/valhalla/timezones.sqlite \
  --mjolnir-admin /data/valhalla/admins.sqlite > valhalla.json

echo "🔧 Updating Valhalla config paths..."
sed -i 's|/var/tmp|/data/valhalla|g' valhalla.json
echo "✅ Valhalla configuration generated."

# ----------------------------------------------------------------

echo "🛠️ [Step 6] Processing OSM Data (Building Tiles)..."
valhalla_build_admins -c valhalla.json hessen-latest.osm.pbf
echo "✅ Admin regions processed."

valhalla_build_tiles -c valhalla.json hessen-latest.osm.pbf
echo "✅ Routing tiles built."

valhalla_build_extract -c valhalla.json -v
echo "✅ Tile extract built."

# ----------------------------------------------------------------

echo "🔄 [Step 7] Setting Up Valhalla as a Systemd Service..."
cat <<EOF > /etc/systemd/system/valhalla.service
[Unit]
Description=Valhalla Routing Engine
After=network.target

[Service]
ExecStart=/usr/local/bin/valhalla_service /data/valhalla/valhalla.json 1
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# Enable and start Valhalla service
systemctl daemon-reload
systemctl enable valhalla.service
systemctl start valhalla.service
echo "✅ Valhalla service set up and started."

# ----------------------------------------------------------------

echo "✅ [Step 8] Testing Valhalla API..."
sleep 5  # Wait for Valhalla to fully start

response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "http://localhost:8002/trace_attributes" -H "Content-Type: application/json" -d '{
  "shape": [{"lat": 50.141, "lon": 8.747}, {"lat": 50.142, "lon": 8.748}],
  "costing": "auto",
  "shape_match": "map_snap"
}')

if [ "$response" -eq 200 ]; then
    echo "✅ Valhalla API is running correctly!"
else
    echo "⚠️ Valhalla API test failed. Check logs."
fi

echo "🎉 Setup Complete! Valhalla is ready to use."