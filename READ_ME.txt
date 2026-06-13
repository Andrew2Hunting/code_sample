The following files and subfolders generate a subset of the dataset used in the paper that I am working on. The paper explores the relation beteween grant funding created by the Inflation Reduction Act (IRA) and labor markets in the continental US. Here are relevant details:

FILE				DESC
----				----
Master_Data			Dataset generated from .do for main analysis
Raw_Data			Data used for dataset from sources online

Raw_Data/BEA_GDP		GDP data from BEA
Raw_Data/BLS			BLS data
Raw_Data/Census_Population	Population data from various US censuses
Raw_Data/Energy_Communities	Data of areas that qualify as energy communities. The IRA planned to give additional funding to communities that were megatively impacted by the impacts of aging energy infrastructure. There are several ways a community can qualify, including proximity to a coal plant, the unemployment rate, etc. 
Raw_Data/IRA			A sample of US grant funds. This includes IRA and non-IRA related funding which will be used as a control in the analysis. 
Raw_Data/MSA			Price level data for select US counties


ALSO, "...\Main\Raw_Data\IRA\GatherSubAwardData" has a file demonstrating my python code. I use python to call data from an API on govspending.gov for relevant sub-grant awards. 