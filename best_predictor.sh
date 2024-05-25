#!/bin/bash

if [ $# -ne 1 ]; then
    echo "Usage: $0 <cleaned_datafile>"
    exit 1
fi

input_file=$1

# Calculating the Pearson correlation coefficient
calculate_correlation() {
    local predictor=$1
    awk -v predictor="$predictor" '
    BEGIN {
        FS = OFS = "\t";
        predictor_idx = -1;
        cantril_idx = -1;
    }
    NR == 1 {
        for (i = 1; i <= NF; i++) {
            if ($i == predictor) predictor_idx = i;
            if ($i == "Cantril ladder score") cantril_idx = i;
        }
        if (predictor_idx == -1 || cantril_idx == -1) {
            print "Error: predictor or Cantril ladder score column not found."
            exit 1;
        }
    }
    NR > 1 {
        country = $1;
        if ($predictor_idx != "" && $cantril_idx != "") {
            count[country]++;
            predictor_sum[country] += $predictor_idx;
            cantril_sum[country] += $cantril_idx;
            predictor_sq_sum[country] += ($predictor_idx)^2;
            cantril_sq_sum[country] += ($cantril_idx)^2;
            predictor_cantril_sum[country] += ($predictor_idx) * ($cantril_idx);
        }
    }
    END {
        for (country in count) {
            if (count[country] >= 3) {
                n = count[country];
                sum_x = predictor_sum[country];
                sum_y = cantril_sum[country];
                sum_x_sq = predictor_sq_sum[country];
                sum_y_sq = cantril_sq_sum[country];
                sum_xy = predictor_cantril_sum[country];
                numerator = (n * sum_xy) - (sum_x * sum_y);
                denominator = sqrt(((n * sum_x_sq) - (sum_x^2)) * ((n * sum_y_sq) - (sum_y^2)));
                if (denominator != 0) {
                    correlation = numerator / denominator;
                    sum_correlations += correlation;
                    valid_counts++;
                }
            }
        }
        if (valid_counts > 0) {
            mean_correlation = sum_correlations / valid_counts;
            print predictor, mean_correlation;
        } else {
            print predictor, "N/A";
        }
    }' "$input_file"
}

# Calculation of the average correlation coefficient for each predictor
predictors=("GDP per capita, PPP (constant 2017 international $)" "Population (historical estimates)" "Homicide rate per 100,000 population - Both sexes - All ages" "Life expectancy - Sex: all - Age: at birth - Variant: estimates")

declare -a predictors_names
declare -a correlations

for predictor in "${predictors[@]}"; do
    result=$(calculate_correlation "$predictor")
    predictor_name=$(echo "$result" | cut -f1)
    mean_correlation=$(echo "$result" | cut -f2)
    predictors_names+=("$predictor_name")
    correlations+=("$mean_correlation")
    echo "Mean correlation of $predictor_name with Cantril ladder is $mean_correlation"
done

best_predictor=""
best_correlation=0

for i in "${!correlations[@]}"; do
    correlation=${correlations[$i]}
    if [ "$correlation" != "N/A" ]; then
        abs_correlation=$(echo "$correlation" | awk '{print ($1 < 0) ? -$1 : $1}')
        if (( $(echo "$abs_correlation > $best_correlation" | bc -l) )); then
            best_correlation=$correlation
            best_predictor=${predictors_names[$i]}
        fi
    fi
done

echo "Most predictive mean correlation with the Cantril ladder is $best_predictor (r = $best_correlation)"
