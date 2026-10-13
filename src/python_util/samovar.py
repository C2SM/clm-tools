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

import pandas as pd
import sys

def main(samovar_csv, var_csv):
    try:
        # Read the CSV files
        try:
            samovar_df = pd.read_csv(samovar_csv)
        except FileNotFoundError:
            print(f"Error: The file {samovar_csv} was not found.")
            return
        except pd.errors.EmptyDataError:
            print(f"Error: The file {samovar_csv} is empty.")
            return
        except pd.errors.ParserError:
            print(f"Error: The file {samovar_csv} could not be parsed.")
            return

        samovar_df.columns = samovar_df.columns.str.replace(' ', '')
        samovar_df = samovar_df.apply(lambda col: col.str.strip() if col.dtype == 'object' and col.apply(lambda x: isinstance(x, str)).all() else col)

        try:
            var_df = pd.read_csv(var_csv, header=None, names=['Name', 'Minimum', 'Maximum'])
        except FileNotFoundError:
            print(f"Error: The file {var_csv} was not found.")
            return
        except pd.errors.EmptyDataError:
            print(f"Error: The file {var_csv} is empty.")
            return
        except pd.errors.ParserError:
            print(f"Error: The file {var_csv} could not be parsed.")
            return

        # Initialize status
        status = 0

        # Process the data
        for _, var_row in var_df.iterrows():
            try:
                min_var = var_row['Minimum']
                max_var = var_row['Maximum']
                var_name = var_row['Name']

                # Check if var_name is in the 'Name' column of samovar_df
                if var_name not in samovar_df['Name'].values:
                    continue

                print(f"INFO -- Checking parameter: {var_name}")
                samovar_row = samovar_df.loc[samovar_df['Name'] == var_name]

                min_sam = samovar_row['Minimum'].values[0]
                max_sam = samovar_row['Maximum'].values[0]

            except KeyError as e:
                print(f"Error: Missing expected column in the data - {e}")
            except IndexError as e:
                print(f"Error: Index error - {e}")
            except Exception as e:
                print(f"Unexpected error: {e}")

    except Exception as e:
        print(f"An unexpected error occurred: {e}")

        if min_var < min_sam:
            if var_name in ['t_snow', 't_ice', 't_bot_lk', 't_wml_lk', 't_mnw_lk'] and min_var == 0:
                print(f"INFO -- {var_name} is an exception with min_var == 0")
            else:
                print(f"ERROR -- {var_name} {min_var} < {min_sam}")
                status = 1

        if max_var > max_sam:
            print(f"ERROR -- {var_name} {max_var} > {max_sam}")
            status = 1

    print('exit status: ', status)
    sys.exit(status)

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("ERROR: invalid number of arguments")
        print("Usage: python samovar.py <samovar_csv> <var_csv>")
        sys.exit(1)

    samovar_csv = sys.argv[1]
    var_csv = sys.argv[2]

    main(samovar_csv, var_csv)
