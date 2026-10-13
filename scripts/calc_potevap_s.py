# ICON-CLM Starter Package (SPICE_v2.4)
#
# ---------------------------------------------------------------
# Copyright (C) 2009-2026, Helmholtz-Zentrum Hereon
# Contact information: https://www.clm-community.eu/
#
# See AUTHORS.TXT for a list of authors
# See LICENSES/ for license information
# SPDX-License-Identifier: GPL-3.0-or-later
#
# SPICE docs: https://hereon-coast.atlassian.net/wiki/spaces/SPICE/overview
# ---------------------------------------------------------------

# Script Description:
# ---------------------------------------------------------------
#  Calculation of potential evapotranspiration from post-processed timeseries
#  of ICON data
#
#  History:
#  Version    Date       Name
#  ---------- ---------- ----
#    1.1      10.07.2024 Shweta Singh, DWD
#                       Initial realise
#    1.2      12.07.2024 Beate Geyer, Hereon
#                       Adaptions to fulfill CF-conventions
# ---------------------------------------------------------------
#
import os
import numpy as np
import xarray as xr
import pandas as pd
import matplotlib.pyplot as plt
import sys

def file_exists(file_path):
    return os.path.exists(file_path)

# Fetch empirical constants dependent on day, night and requested time frequency (daily/hourly)
class WeatherData:
    def __init__(self):
        self.cn_short_daily = 900
        self.cd_short_daily = 0.34
        self.cn_short_hourly_day = 37
        self.cd_short_hourly_day = 0.24
        self.cn_short_hourly_night = 37
        self.cd_short_hourly_night = 0.96
        # Tall reference
        self.cn_tall_daily =1600
        self.cd_tall_daily = 0.38
        self.cn_tall_hourly_day = 66
        self.cd_tall_hourly_day = 0.25
        self.cn_tall_hourly_night = 66
        self.cd_tall_hourly_night = 1.7

        # Soil heat flux density (G):
        self.G_short_daily=0
        self.G_tall_daily=0
        self.G_short_daytime=0.1
        self.G_short_nighttime=0.5
        self.G_tall_daytime=0.04
        self.G_tall_nighttime=0.2


    def daily_constants(self, reference):
        if reference=="short":
            return self.cn_short_daily, self.cd_short_daily, self.G_short_daily
        elif reference=="tall":
            return self.cn_tall_daily, self.cd_tall_daily, self.G_tall_daily
        else:
            print("Reference not defined. Select from short and tall.")

    def hourly_constants(self, reference, time_of_day):
        if reference=="short" and time_of_day=="day":
            return self.cn_short_hourly_day, self.cd_short_hourly_day, self.G_short_daytime
        elif reference=="short" and time_of_day=="night":
            return self.cn_short_hourly_night, self.cd_short_hourly_night, self.G_short_nighttime
        elif reference=="tall" and time_of_day=="day":
            return self.cn_tall_hourly_day, self.cd_tall_hourly_day, self.G_tall_daytime
        elif reference=="tall" and time_of_day=="night":
            return self.cn_tall_hourly_night, self.cd_tall_hourly_night, self.G_tall_nighttime
        else:
            print("Reference not defined. Select from short and tall.")

def saturation_vapor_pressure(temperature):
    e_s=0.6108 * np.exp(17.27 * temperature / (temperature + 237.3))
    return e_s

def actual_vap_pressure_from_ps_qv_2m(ps,qv_2m):
    pvap_2m = qv_2m * ps / (0.622 + 0.378 * qv_2m)
    return pvap_2m

def actual_vap_pressure_from_t_rh_2m(t_2m,rh_2m):
    pvap_2m = np.where(t_2m >= 273.15,6.112 * rh_2m * np.exp(17.62 * (t_2m - 273.15) / (t_2m - 30.03)),6.112 * rh_2m * np.exp(22.46 * (t_2m - 273.15) / (t_2m - 0.53)))
    return pvap_2m

ref_type="short"
ipath = sys.argv[1]
# Input variables
ds_t2m=xr.open_dataset(ipath+"AT_2M_ts.nc")         # Hourly mean Temperature 2m
#ds_rh2m=xr.open_dataset(ipath+"ARELHUM_2M_ts.nc")  # Hourly mean relative humidity 2m
#ds_pvap_2m=xr.open_dataset(ipath+"PVAP_2M_ts.nc")  # Hourly mean actual vapor pressure at 2m
ds_sp_10m=xr.open_dataset(ipath+"ASP_10M_ts.nc")    # Hourly mean wind speed at 10m
ds_shfl=xr.open_dataset(ipath+"ASHFL_S_ts.nc")      # Hourly mean surface sensible heat flux
ds_lhfl=xr.open_dataset(ipath+"ALHFL_S_ts.nc")      # Hourly mean surface latent heat flux
ds_sw=xr.open_dataset(ipath+"ASOB_S_ts.nc")         # Hourly mean surface net SW radiaiton in W/m2
ds_lw=xr.open_dataset(ipath+"ATHB_S_ts.nc")         # Hourly mean surface net LW radiaiton in W/m2

# input files for actual vapor pressure calculation
infile1="APS_ts.nc"         # Hourly mean surface pressure
infile2="AQV_2M_ts.nc"      # Hourly mean sepcific humidity 2m
infile3="AT_2M_ts.nc"       # Hourly mean temperature at 2m
infile4="ARELHUM_2M_ts.nc"  # Hourly mean relative humidity 2m

var_altitude = 2  # Assuming a default altitude of 2 meters
var_wind_height = 10  # Assuming wind height is 10 meters

# Natural constants
c_p = 1.013e-3  # specific heat at constant pressure [MJ kg-1 °C-1]
epsilon = 0.622  # ratio molecular weight of water vapor/dry air
lambda_val = 2.45  # latent heat of vaporization [MJ kg-1]
pi = np.pi

unit_hourly=0.0036
unit_daily=0.0864

var_tmean = ds_t2m['AT_2M'].values-273.15 # from K to degree C
#var_rh2m = ds_rh2m['ARELHUM_2M'].values   # %
#e_a = ds_pvap_2m['PVAP_2M']/1000          # from Pa to kPa

# Check input files for actual vapor pressure
if file_exists(ipath+infile1) and file_exists(ipath+infile2):
    ds1=xr.open_dataset(ipath+infile1)
    ds2=xr.open_dataset(ipath+infile2)
    ps=ds1["APS"].values
    qv_2m=ds2["AQV_2M"].values
    e_a=actual_vap_pressure_from_ps_qv_2m(ps,qv_2m)

elif file_exists(ipath+infile3) and file_exists(ipath+infile4):
    ds1=xr.open_dataset(ipath+infile3)
    ds2=xr.open_dataset(ipath+infile4)
    t_2m=ds1["AT_2M"].values
    rh_2m=ds2["ARELHUM_2M"].values
    e_a=actual_vap_pressure_from_t_rh_2m(t_2m,rh_2m)

else:
    print('Input files for calculation of actual vapor pressure are missing!')
    sys.exit(1)

e_a=e_a/1000    # from Pa to kPa

var_wind = ds_sp_10m['ASP_10M'].values    # m/s
R_ns = ds_sw['ASOB_S']*unit_hourly        # from W/m2 to MJm-2 # 1 W/m2 = 1 J/m2/s  = 0.0864 MJ/m2/day = 0.0036 MJ/m2/hour
R_nl = ds_lw['ATHB_S']*unit_hourly        # from W/m2 to MJm-2
H = ds_shfl['ASHFL_S']*unit_hourly        # from W/m2 to MJm-2
E = ds_lhfl['ALHFL_S']*unit_hourly        # from W/m2 to MJm-2

var_altitude = 2  # Assuming a default altitude of 2 meters
var_wind_height = 10  # Assuming wind height is 10 meters

FAO56_PMconstants = WeatherData()
#C_n=xr.where(R_ns<=0,FAO56_PMconstants.hourly_constants(reference=ref_type,time_of_day="night")[0],xr.where(R_ns>0,FAO56_PMconstants.hourly_constants(reference=ref_type,time_of_day="day")[0],0))
#C_n=C_n.values

C_n=37 # Singer (2021) https://doi.org/10.1038/s41597-021-01003-9

#C_d=xr.where(R_ns<=0,FAO56_PMconstants.hourly_constants(reference=ref_type,time_of_day="night")[1],xr.where(R_ns>0,FAO56_PMconstants.hourly_constants(reference=ref_type,time_of_day="day")[1],0))
#C_d=C_d.values

C_d=0.34 # Singer (2021) https://doi.org/10.1038/s41597-021-01003-9


# Calculations
# MEAN TEMPERATURE: hourly mean temperature [°C]
T_mean = var_tmean #

# VAPOR PRESSURE DEFICIT [kPa]
pressure = 101.3 * (((293 - 0.0065 * var_altitude) / 293) ** 5.26)
gamma = (c_p * pressure) / (epsilon * lambda_val)  # psychrometric constant [kPa °C-1]

e_sat = saturation_vapor_pressure(var_tmean) 

e_deficit = e_sat - e_a

# SLOPE OF SATURATION VAPOUR PRESSURE CURVE [kPa °C-1]
delta = (4098 * (0.6108 * np.exp(17.27 * T_mean / (T_mean + 237.3)))) / ((T_mean + 237.3) ** 2)

# WIND SPEED [m s-1]
u2 = var_wind * 4.87 / np.log(67.8 * var_wind_height - 5.42)  # wind speed 10m -> 2m above ground

# Net radiation [MJ m-2 h-1]
R_n = R_ns - R_nl
#G = 0  # estimated soil heat flux for daily periods [MJ m-2]
G=xr.where(R_ns<=0,R_n*FAO56_PMconstants.hourly_constants(reference=ref_type,time_of_day="night")[2],xr.where(R_ns>0,R_n*FAO56_PMconstants.hourly_constants(reference=ref_type,time_of_day="day")[2],0))

# Hourly potential evapotranspiration APOTEVAP_S [mm h-1]

# Using R_n-G
APOTEVAP_S = (0.408 * delta * (R_n - G) + gamma * (C_n / (T_mean + 273)) * u2 * e_deficit) / (delta + gamma * (1 + C_d * u2))

# Using H+E
#APOTEVAP_S = (0.408 * delta * (H + E) + gamma * (C_n / (T_mean + 273)) * u2 * e_deficit) / (delta + gamma * (1 + C_d * u2))

APOTEVAP_S=xr.DataArray(APOTEVAP_S, attrs = {"long_name": "Potential evapotranspiration", "standard_name": "water_potential_evapotranspiration_amount", "units": "kg m-2","grid_mapping":"rotated_pole","cell_methods":"time: sum",},coords={'time': ds_t2m.time, 'rlat': ds_t2m.rlat, 'rlon': ds_t2m.rlon},dims=['time', 'rlat', 'rlon'])

#APOTEVAP_S_mean=APOTEVAP_S.resample(time='D').mean(dim=['rlat', 'rlon'])
#print(APOTEVAP_S_mean)

#ds_APOTEVAP_S = xr.Dataset({"APOTEVAP_S": APOTEVAP_S, "lon": ds_t2m.lon, "lon_bnds": ds_t2m.lon_bnds, "lat": ds_t2m.lat, "lat_bnds": ds_t2m.lat_bnds, "rotated_pole": ds_t2m.rotated_pole, "time_bnds": ds_t2m.time_bnds})

ds_APOTEVAP_S = xr.Dataset({"APOTEVAP_S": APOTEVAP_S, "lon": ds_t2m.lon, "lon_bnds": ds_t2m.lon_bnds, "lat": ds_t2m.lat, "lat_bnds": ds_t2m.lat_bnds, "rotated_pole": ds_t2m.rotated_pole, "time_bnds": ds_t2m.time_bnds})


ds_APOTEVAP_S.attrs = ds_t2m.attrs 
ds_APOTEVAP_S.attrs['history'] = "FAO56 Penman-Monteith equation, Allen (2005), Singer (2021) Nature, based hourly PET"

#encoding={'lat': {'_FillValue': None},'lon': {'_FillValue': None}, 'lat_bnds': {'_FillValue': None},'lon_bnds': {'_FillValue': None},'rlat': {'_FillValue': None},'rlon': {'_FillValue': None},'height_2m': {'_FillValue': None},'time': {'_FillValue': None},'time_bnds': {'_FillValue': None},'APOTEVAP_S': {'_FillValue': -1.e+20}}
encoding={'lat': {'_FillValue': None},'lon': {'_FillValue': None}, 'lat_bnds': {'_FillValue': None},'lon_bnds': {'_FillValue': None},'rlat': {'_FillValue': None},'rlon': {'_FillValue': None},'height_2m': {'_FillValue': None},'time': {'_FillValue': None, 'dtype': 'float64'},'time_bnds': {'_FillValue': None, 'dtype': 'float64'},'APOTEVAP_S': {'_FillValue': -1.e+20}}
ds_APOTEVAP_S.to_netcdf(ipath+'APOTEVAP_S_ts.nc',encoding=encoding)
