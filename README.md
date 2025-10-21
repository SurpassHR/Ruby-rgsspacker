# Ruby-rgsspacker

I don't know much about Ruby or RGSS, but thanks to [SiCrane](https://www.gamedev.net/sicrane) for his [Ruby code](http://www.gamedev.net/forums/topic/646333-rpg-maker-vx-ace-data-conversion-utility/5083723/) on RGSS parsing, I can make this [RPG-extractor](https://github.com/SurpassHR/RPG-extractor) tool for extracting data from RGSS files.

I added `rgss_extractor.rb` to use SiCrane's code, it provides command line functionality for external calling.

```bash
# To convert one rxdata file to a readable yaml file:
ruby ./rgss_extractor.rb -i <path_to_specific_rxdata_file> -o <path_to_output_file>
# To convert a list of rxdata files to readable yaml files:
ruby ./rgss_extractor.rb -I <list_of_rxdata_files_seperated_by_comma> -O <list_of_output_files_seperated_by_comma>
# To convert a directory's rxdata files to readable yaml files:
ruby ./rgss_extractor.rb -S <path_to_source_directory> -D <path_to_destination_directory> -T <target_file_extension>
```

All credits go to SiCrane.
