SHELL := /bin/bash
.PHONY: extern parser-bench parser-profile parser-stat parser-flame clean

codegen = 0
ifneq ($(codegen), 0)
	codegenflag = --codegen
else
	codegenflag =
endif

parser = "parser"
files = cat extern/list.txt
rate = 10000
out = $(parser)
limit = 10

extern:
	@rm -rf extern
	@for url in $$(cat extern.txt); do \
		echo "downloading $$url"; \
		curl -s -L $$url -o extern.zip; \
		echo "unzipping $$url"; \
		unzip -qq -o extern.zip -d extern; \
	done
	@rm extern.zip

	@# remove all non-luau files and empty directories
	@find "extern" -type f ! \( -name "*.lua" -o -name "*.luau" \) -delete
	@find "extern" -type d -empty -delete

	@# remove specific problematic files
	@rm -r extern/NevermoreEngine-main/tools
	@rm -r extern/Adonis-master/Loader/Config/Plugins
	@rm -r "extern/Adonis-master/MainModule/Client/UI/Windows XP"
	@rm "extern/Adonis-master/MainModule/Client/Dependencies/Theming_Info [Read].luau"

	@echo "return {" >> files.luau

	@# modify all files to return a string of themselves
	@for file in $$(find "extern" -type f); do \
		content=$$(cat "$$file"); \
		echo "local str = [===[$$content]===]; return { str = str }" > "$$file"; \
		echo "    '$$file'," >> files.luau; \
	done

	@echo "}" >> files.luau
	@mv files.luau extern/files.luau

parser-bench:
	luau scripts/parserbench.luau $(codegenflag) -a $(parser)

parser-profile:
	@mkdir profile -p
	luau scripts/parserbench.luau $(codegenflag) --profile=$(rate) -a $(parser)
	@mv profile.out profile/$(out).out

parser-stats: parser-profile
	@chmod +x scripts/perfstat.py
	@scripts/perfstat.py profile/$(out).out --limit=$(limit)

parser-flame: parser-profile
	@chmod +x scripts/perfgraph.py
	@scripts/perfgraph.py profile/$(out).out > profile/$(out).svg

clean:
	@rm -r profile
	@rm -r scripts/__pycache__
	@rm -r extern
	@echo "cleaned"