#########################################################################
# Track description file for VCWC.				        #
# 								        #
# Copyright (C) 2013  Thomas Krennwallner <tkren@kr.tuwien.ac.at>       #
# Copyright (C) 2013  Martin Schwengerer <mschweng@kr.tuwien.ac.at>     #
# 								        #
# This file is part of VCWC.					        #
# 								        #
#  VCWC is free software: you can redistribute it and/or modify	        #
#  it under the terms of the GNU General Public License as published by #
#  the Free Software Foundation, either version 3 of the License, or    #
#  (at your option) any later version.				        #
# 								        #
#  VCWC is distributed in the hope that it will be useful,	        #
#  but WITHOUT ANY WARRANTY; without even the implied warranty of       #
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the        #
#  GNU General Public License for more details.			        #
# 								        #
#  You should have received a copy of the GNU General Public License    #
#  along with VCWC.  If not, see <http://www.gnu.org/licenses/>.        #
#########################################################################


# trackname
TRACK=t01
SYSTEMTRACK=

# input
TRACK_DIR=/home/aspcomp
PARTICIPANTS_DIR=$(TRACK_DIR)/participants/$(TRACK)
BENCHMARKS_DIR=$(TRACK_DIR)/benchmarks/$(TRACK)
OUTPUTPRED_DIR=$(TRACK_DIR)/output

EXEC_DIR=/home/aspexec
CHECK_DIR=/home/aspck
STATS_DIR=/home/aspstat

# condor submit description files
CONDOR_SUBMIT_DESCRIPTIONS_DIR=$(TRACK_DIR)/condor-seq

# output
DAGMAN_DIR=$(STATS_DIR)/dagman/$(TRACK)
PROFILE_DIR=$(STATS_DIR)/profiles/$(TRACK)

# find participant names
#PARTICIPANTS := $(shell find $(PARTICIPANTS_DIR) -maxdepth 1 -mindepth 1 -type d -printf "%f ")
PARTICIPANTS := $(shell find -L $(PARTICIPANTS_DIR) -maxdepth 2 -mindepth 2 -type d -printf "%P ")

# find benchmark instances in filename format: $(BENCHMARKS_DIR)/b06/instances/42-my_benchmark-166-2.asp becomes b06/42-my_benchmark-166-2.asp
INSTANCES_DIRNAME=instances
INSTANCES := $(subst $(INSTANCES_DIRNAME)/,,$(shell find -L $(BENCHMARKS_DIR) -maxdepth 3 -path "*$(BENCHMARKS_DIR)/*/$(INSTANCES_DIRNAME)/*" -printf "%P "))

# get sorted list benchmark names
BENCHMARKS := $(sort $(subst /,,$(dir $(INSTANCES))))

# generate instances in zero padded format: b06/42-my_benchmark-166-2.asp becomes b06/i042
#NUM_INSTANCES := $(foreach b,$(BENCHMARKS),$(foreach i,$(notdir $(filter $(b)/%, $(INSTANCES))),$(b)/$(addprefix i,$(shell printf "%0.3d" $(firstword $(subst -,$(space),$(i)))))))
NUM_INSTANCES := $(foreach b,$(BENCHMARKS),$(foreach i,$(notdir $(filter $(b)/%, $(INSTANCES))),$(b)/$(addprefix i,$(firstword $(subst -,$(space),$(i))))))

NUM_RUNS_START := 0
NUM_RUNS_END := 2

# generate list of zero padded runs: r$(NUM_RUNS_START) .. r$(NUM_RUNS_END)
RUNS := $(shell seq -f 'r%03.f' -s ' ' $(NUM_RUNS_START) $(NUM_RUNS_END))

## Local Variables:
## mode: makefile-gmake
## End:
