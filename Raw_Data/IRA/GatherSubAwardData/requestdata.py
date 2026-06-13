import os
import json
import time
import requests
import pandas as pd

def get_fips(state_abbr):
    df_states = pd.read_csv('/home/ubuntu/data5500_mycode/final_project/StateFips.csv', dtype={'FIPS': str})
    # Look for the row where 'Abbreviation' matches, and return the 'FIPS' value
    result = df_states.loc[df_states['Abbreviation'] == state_abbr, 'FIPS']
    return result.iloc[0] if not result.empty else None

def get_subawards_safely(input_csv_path, output_csv_path, id_column_name="Prime Award ID"):
    url = "https://api.usaspending.gov/api/v2/search/spending_by_award/"
    headers = {"Content-Type": "application/json"}
    
    columns_to_extract = [
        "Sub-Award Amount",
        "Prime Award ID",
        "Sub-Award Date",
        "Sub-Award Description",
        "Sub-Recipient Location",
        "Sub-Award Primary Place of Performance"
    ]

    # Load list of ids
    if not os.path.exists(input_csv_path):
        print(f"Error: Input file '{input_csv_path}' not found.")
        return

    df_input = pd.read_csv(input_csv_path)
    all_input_ids = df_input[id_column_name].dropna().unique().tolist()
    print(f"Total unique IDs in master list: {len(all_input_ids)}")

    # Logic to resume
    already_processed_ids = set() 
    
    if os.path.exists(output_csv_path):
        try:
            df_existing = pd.read_csv(output_csv_path, usecols=["Prime Award ID"])
            already_processed_ids = set(df_existing["Prime Award ID"].dropna().unique())
            print(f"Resume Status: Found {len(already_processed_ids)} IDs safely saved in '{output_csv_path}'.")
        except ValueError:
            print("Output file exists but appears empty. Starting from scratch.")
        except Exception as e:
             print(f"Warning reading output file: {e}. Starting from scratch.")

    # Filter the master list: Keep only IDs that are NOT in the already_processed set
    ids_to_process = [award_id for award_id in all_input_ids if award_id not in already_processed_ids]
    
    total_remaining = len(ids_to_process)
    if total_remaining == 0:
        print("Success: All IDs have already been processed. Nothing left to do!")
        return

    print(f"Starting extraction for the remaining {total_remaining} IDs...")

    # Calling Api for each id
    for index, award_id in enumerate(ids_to_process, 1):
        print(f"[{index}/{total_remaining}] Fetching: {award_id}")
        
        page = 1
        has_next = True
        seen_combinations = set()

        MAX_RETRIES = 3
        RETRY_DELAY = 5

        while has_next:
            payload = {
                "filters": {
                    "time_period": [{"start_date": "2007-10-01", "end_date": "2026-09-30"}],
                    "award_type_codes": ["02","03","04","05","F001","F002","10","06","F006","F007","07","08","F003","F004","09","11","-1","F005","F010"],
                    "award_ids": [award_id]
                },
                "page": page,
                "limit": 100,
                "sort": "Sub-Award Amount",
                "order": "desc",
                "spending_level": "subawards",
                "fields": columns_to_extract
            }

            success = False
            for attempt in range(MAX_RETRIES):
                try:
                    response = requests.post(url, headers=headers, json=payload, timeout=30)
                    response.raise_for_status()
                    data = response.json()
                    success = True
                    break 

                except requests.exceptions.RequestException as e:
                    print(f"   ! API Error on {award_id} (Page {page}), attempt {attempt + 1}/{MAX_RETRIES}: {e}")
                    if attempt < MAX_RETRIES - 1:
                        print(f"     Retrying in {RETRY_DELAY} seconds...")
                        time.sleep(RETRY_DELAY)
                    else:
                        print(f"     Max retries reached. Logging failure.")
                        # Append the failed ID and page to a text file
                        with open("failed_award_ids.txt", "a") as f:
                            f.write(f"{award_id},page_{page}\n")

            if not success:
                break

            results = data.get("results", [])
                                
            # Removing Duplicates
            filtered_results = []
            for record in results:
                row_signature = (
                    record.get("Sub-Award Amount"),
                    record.get("Prime Award ID"),
                    record.get("Sub-Award Date")
                )
                if row_signature not in seen_combinations:
                    seen_combinations.add(row_signature)  
                    filtered_results.append(record)       
            
            results = filtered_results

            # Saving Logic
            if results:
                batch = []
                for record in results:
                    processed_record = {}
                    for col in columns_to_extract:
                        value = record.get(col)
                        
                        if isinstance(value, dict): 
                            state = value.get("state_code")
                            county = value.get("county_code")
                            
                            # Only process if BOTH state and county exist
                            if state and county:
                                fips = get_fips(state)
                                if fips is not None:
                                    processed_record[col] = str(fips) + str(county)
                                else:
                                    processed_record[col] = None # Unknown state abbreviation
                            else:
                                processed_record[col] = None # Missing state or county data
                        else:
                            processed_record[col] = value
                    batch.append(processed_record)
                
                batch_df = pd.DataFrame(batch)
                file_already_exists = os.path.isfile(output_csv_path)
                batch_df.to_csv(output_csv_path, mode='a', index=False, header=not file_already_exists)

            page_metadata = data.get("page_metadata", {})
            has_next = page_metadata.get("hasNext", False)
            page += 1
            
            time.sleep(0.2)


    print(f"\nExtraction complete. Your data is secure in: {output_csv_path}")

if __name__ == "__main__":
    
    INPUT_FILE = "/home/ubuntu/data5500_mycode/final_project/awardids_complete.csv"
    OUTPUT_FILE = "/home/ubuntu/data5500_mycode/final_project/results/all_subawards_results.csv"
    COLUMN_NAME = "award_id" 

    get_subawards_safely(INPUT_FILE, OUTPUT_FILE, COLUMN_NAME)    
    
