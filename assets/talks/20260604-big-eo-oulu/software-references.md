# Software & standards — reference notes

Companion to `data-references.md`. Covers the open-source / open-standards material on Part 1 slides 6 ("The software response") and 7 ("From files to APIs"). Synthesised from the planning discussions and the live state of the field in 2025–2026.

---

## 1. The three boxes on slide 6 ("The software response")

The taxonomy is **bytes → wires → code**, or in CS terms **storage layer → service layer → client/application layer**.

| Box | What it groups | One-line meaning | Items |
|---|---|---|---|
| **Open formats** | *Standards for how bytes are laid out on disk* | "How data is structured so cloud tools can stream slices efficiently" | COG · Zarr · GeoParquet · NetCDF · HDF5 |
| **Open APIs** | *Standards for how to find and act on data over the network* | "How clients discover what exists and submit processing requests" | STAC (discovery) · openEO (processing) · OGC API · CEOS ARD |
| **Open libraries** | *Software that uses those formats and APIs to do work* | "The code scientists actually write or call" | xarray · Dask · Pangeo · GDAL · rasterio · pystac · ODC |

This is the meta-message of the slide: the community didn't write one big monolithic system; it agreed on three thin layers of open standards and built libraries on top.

---

## 2. STAC is *not* purely an API — but the label is defensible

STAC has two parts:

| Layer | Nature | Example |
|---|---|---|
| **STAC core spec** | JSON **metadata standard** (`Catalog → Collection → Item → Asset`) | Static JSON files in a bucket — no server |
| **STAC API spec** | REST API on top of OGC API – Features | Dynamic search by bbox/datetime/property |

Strictly: STAC core = data model, STAC API = an API on top of it. In production, almost every major STAC deployment (Microsoft Planetary Computer, AWS Open Data, Earth Search, Copernicus Data Space) exposes both — so calling STAC an "open API" on a slide is defensible, just understand the core is a metadata standard.

**openEO**, by contrast, is *primarily* an API specification (process-graph REST API) — no static form.

Cleanest split on the slide:
- **STAC = discovery**
- **openEO = processing**

(Both shown explicitly under the middle box's `extras` line.)

---

## 3. "Data is now an API, not a file you download"

A rhetorical slogan with a real underlying shift. Strictly accurate version: *"the **access pattern** is now an API call, not a download."*

| Old pattern | New pattern |
|---|---|
| Download a 1 GB SAFE archive | `GET /scene.tif Range: bytes=...` HTTP range query |
| Reproject and mosaic locally | Hit a STAC endpoint → JSON of matching items |
| Run your code on your laptop | Submit an openEO process graph → backend runs it next to the data |

The bytes are still files on disk at the bottom. What changed is the **access pattern**: from "bulk download → local processing" to "query + stream slices on demand → analyse next to the data".

---

## 4. What "S3" means on slide 7

Two meanings, both relevant:
1. **Literal AWS S3** — Amazon's object-storage service (since 2006); where most "Open Data on AWS" lives (Sentinel-2 COGs, Landsat, etc.).
2. **S3-compatible object storage** — the AWS S3 HTTP API is now a de-facto standard, also spoken by MinIO, Cloudflare R2, Wasabi, IBM Cloud Object Storage, and Azure Blob via gateway.

⚠️ **Ambiguity on a Copernicus slide**: "S3" also means **Sentinel-3** (ESA's ocean/land mission). On slide 7 we replaced "S3" with **"cloud object storage"** to remove the collision.

---

## 5. ESA EOPF — what's actually new

Cloud-native EO is **not new**. Many providers have been doing STAC + COG / Zarr for years:

| Provider | Adoption |
|---|---|
| AWS Open Data | Sentinel-2 COGs since ~2017, STAC catalogs since ~2020 |
| Microsoft Planetary Computer | STAC + COG/Zarr since 2021 |
| Earth Search (Element-84) | STAC since 2018 |
| Sentinel Hub (Sinergise) | Commercial API for years |
| Google Earth Engine | Proprietary equivalent since 2010 |
| Pangeo / ARCO climate data | Zarr-native since ~2019 |
| Digital Earth Australia | Open Data Cube + Zarr |

**What is new in 2025–2027**: ESA itself — the *source* of Sentinel data — adopting **Zarr as the primary, official distribution format**. That's the **EOPF (Earth Observation Product Format)** project, going operational late 2026 / early 2027.

Before EOPF: ESA publishes SAFE archives; third-party clouds reformat to COG / Zarr.
After EOPF: ESA publishes Zarr natively — the whole upstream chain becomes cloud-native by default.

The Before/After framing on slide 7 was rewritten to make this distinction explicit ("Until now" / "From 2026/27").

---

## 6. Quick reference — what each tool/standard is

### Formats

- **COG (Cloud-Optimized GeoTIFF)** — a regular GeoTIFF whose internal layout (header up front, tiled pixel data, overviews) lets clients pull arbitrary subsets via HTTP range requests. OGC standard (ratified 2023).
- **Zarr** — chunked N-dimensional arrays stored as object-store keys. Metadata in JSON. Pluggable codecs. v3 standardised 2024.
- **GeoParquet** — Apache Parquet (columnar tabular) + geospatial extension. Replacing Shapefile / GeoPackage for cloud-native vector data.
- **NetCDF / HDF5** — older scientific multidim formats; still common (especially climate, ocean).

### Catalogs / APIs

- **STAC (SpatioTemporal Asset Catalog)** — metadata spec + optional REST API for searching EO assets. v1.1 (2024). Standardised across AWS Open Data, Microsoft Planetary Computer, Earth Search, ESA Copernicus Data Space.
- **openEO** — REST API standard for sending EO process graphs to a backend that returns processed results. Federated: same API across multiple providers (Copernicus Data Space, Earth Search, Planetary Computer). Seeking **OGC Community Standard** status (2025).
- **OGC API – Features / Coverages / Tiles** — newer "REST-y" successors to the older WFS / WCS / WMTS specs.
- **CEOS ARD** — specifies what "Analysis-Ready Data" means (per-pixel QA, harmonised reflectance / backscatter, common grid, provenance).

### Libraries

- **GDAL / PROJ** — foundational C/C++ libraries for raster / vector I/O and coordinate transformations. Behind almost everything else.
- **xarray** — labelled N-dim arrays (Python). The de-facto interface for working with EO cubes.
- **Dask** — parallel task scheduler. Pairs with xarray to scale from laptop to cluster.
- **rasterio** — Python raster I/O on top of GDAL.
- **pystac / pystac-client** — Python clients for static and dynamic STAC catalogs.
- **Open Data Cube (ODC)** — framework for indexing and analysing EO data cubes. Powers DEA, DE Africa, Swiss Data Cube.
- **Pangeo** — community + reference architecture (not a library): Kubernetes + JupyterHub + Dask + xarray + Zarr.
- **gdalcubes** (R), **sits** (R), **xcube**, **sen2cube** — domain-specific datacube libraries.

---

## 7. EOPF — direct references

- ESA EOPF Zarr landing page: <https://zarr.eopf.copernicus.eu/>
- EOPF Sentinel Zarr Explorer (live demo): <https://explorer.eopf.copernicus.eu/>
- ESA EOPF framework page: <https://eopf.copernicus.eu/eopf/>
- ESA EOPF Toolkit (GitHub): <https://github.com/eopf-toolkit>

---

## 8. Cross-check sources for the slide claims

- [openEO seeks OGC Community Standard status](https://www.ogc.org/requests/ogc-considering-openeo-as-a-community-standard-comment-sought-on-its-adoption/)
- [Cloud-Native Geospatial at LPS 2025](https://vorgeo.github.io/lps25-cng/)
- [openEO platform](https://openeo.org/)
- [STAC spec](https://stacspec.org/)
- [Zarr](https://zarr.dev/)
- [Pangeo community](https://pangeo.io/)
- [Cloud-Optimized GeoTIFF (cogeo.org)](https://www.cogeo.org/)
- [GeoParquet](https://geoparquet.org/)
- [CEOS ARD](https://ceos.org/ard/)

---

## 9. Slide-deck wording decisions

- **Middle box header**: kept as **"Open APIs"** rather than splitting into "catalogs & processing APIs", on the grounds that STAC API is first-class in every major deployment. Subtitle / extras line carry the STAC = discovery / openEO = processing distinction explicitly.
- **"S3"**: replaced with **"cloud object storage"** on slide 7 to remove the Sentinel-3 ambiguity.
- **"Data is now an API"**: softened to **"Access is now an API call, not a file download"** — same shift, more accurate phrasing.
- **Before / After**: reframed as **"Until now" / "From 2026/27"** anchored on EOPF, so audience doesn't mistake the slide as suggesting cloud-native EO didn't exist before.

---

*Last updated: 2026-05-30. Maintainer: Victor Maus.*
