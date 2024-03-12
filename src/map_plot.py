"""
Author: Flavio Gjoni
Status: IN-PROGRESS
Description: With this code we can map the filtered CSV with geopandas and have a visual look at it
"""
import pandas as pd
import geopandas as gpd
import matplotlib.pyplot as plt
import sys

def load_data(filepath):
    return pd.read_csv(filepath)

# Map countries to colors based on matching status
def map_country_colors(df):
    def determine_color(group):
        if (group['CountryMatched'] == 'Match').all():
            return 'match'  # All entries are 'Match'
        else:
            return 'not match'  # At least one entry is 'Not Match' or 'Manual'
    
    return df.groupby('source.geo.country_name').apply(determine_color).reset_index(name='color')

# Identify unmatched country names between the CSV and the geopandas world dataset
def get_unmatched_countries(df, world):
    dataset_countries = set(df['source.geo.country_name'].unique())
    world_countries = set(world['name'].unique())
    return dataset_countries - world_countries

def plot_world_map(world, country_colors):
    # fig, ax = plt.subplots(1, figsize=(15, 10))
    ax = world.boundary.plot(edgecolor='black', linewidth=0.2, figsize=(15,10))
    world.plot(column='color', ax=ax, 
               legend=True, missing_kwds={'color': 'lightgrey'},
               cmap='RdYlGn')
    ax.get_xaxis().set_visible(False)
    ax.get_yaxis().set_visible(False)
    # ax.set_title('Mapped alerts around the world', size=18, weight='bold')
    plt.show()

def apply_known_country_mappings(df, mappings):
    df['source.geo.country_name'] = df['source.geo.country_name'].map(mappings).fillna(df['source.geo.country_name'])
    return df

def main():
    known_country_mappings = {
        "United States": "United States of America",
        "The Netherlands": "Netherlands",
        "Hong Kong": "China",  # Hong Kong is part of China in the geopandas dataset
        "Singapore": "Malaysia"  # Singapore // // // Malaysia // // // //
        # ...
    }

    df = load_data('..\\filtered_alerts_all.csv') # use data\...
    df = apply_known_country_mappings(df, known_country_mappings)

    country_colors = map_country_colors(df)
    world = gpd.read_file(gpd.datasets.get_path('naturalearth_lowres'))
    unmatched_countries = get_unmatched_countries(df, world)
    
    if unmatched_countries:
        print(f"Unmatched countries: {unmatched_countries}")
        sys.exit("Address the unmatched countries before proceeding.")

    world = world.merge(country_colors, how="left", left_on='name', right_on='source.geo.country_name')
    plot_world_map(world, country_colors)

    # Save the figure if desired
    # fig.savefig('data\alerts_mapped.png')

if __name__ == '__main__':
    main()
