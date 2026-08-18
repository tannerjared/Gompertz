BEGIN {
  OFS = ","
}

function between(code, lower, upper) {
  return code >= lower && code <= upper
}

function classify(icd, base, letter, number) {
  base = substr(icd, 1, 3)
  letter = substr(base, 1, 1)
  number = substr(base, 2, 2) + 0

  if (icd == "U071") return "COVID-19"

  if ((letter == "X" && ((number >= 40 && number <= 44) ||
                          (number >= 60 && number <= 64) || number == 85)) ||
      (letter == "Y" && number >= 10 && number <= 14)) return "Drug overdose"

  if (base == "E24" && icd == "E244" || base == "F10" || icd == "G312" ||
      icd == "G621" || icd == "G721" || icd == "I426" || icd == "K292" ||
      base == "K70" || icd == "K852" || icd == "K860" || icd == "Q860" ||
      icd == "R780" || base == "X45" || base == "X65" || base == "Y15")
    return "Alcohol-induced"

  if (base == "U03" || (letter == "X" && number >= 60 && number <= 84) ||
      icd == "Y870") return "Suicide"

  if (base == "U01" || base == "U02" ||
      (letter == "X" && number >= 85 && number <= 99) ||
      (letter == "Y" && number >= 0 && number <= 9) || icd == "Y871")
    return "Homicide"

  if (letter == "C") return "Cancer"

  if (letter == "I" && ((number >= 0 && number <= 9) || number == 11 ||
                         number == 13 || (number >= 20 && number <= 51)))
    return "Heart disease"

  if (letter == "I" && number >= 60 && number <= 69) return "Stroke"
  if (letter == "E" && number >= 10 && number <= 14) return "Diabetes"
  if (letter == "J" && number >= 40 && number <= 47) return "Chronic lower respiratory disease"
  if (base == "G30") return "Alzheimer disease"

  if ((letter == "V") ||
      (letter == "X" && ((number >= 0 && number <= 39) || (number >= 46 && number <= 59))) ||
      base == "Y85" || base == "Y86") return "Other unintentional injury"

  return "Other causes"
}

{
  unit = substr($0, 70, 1)
  age_text = substr($0, 71, 3)
  if (unit != "1" || age_text !~ /^[0-9][0-9][0-9]$/) next
  age = age_text + 0
  if (age < age_min || age > age_max) next
  sex = substr($0, 69, 1)
  if (sex != "M" && sex != "F") next
  icd = substr($0, 146, 4)
  cause = classify(icd)
  count[year SUBSEP age SUBSEP sex SUBSEP cause]++
}

END {
  for (key in count) {
    split(key, part, SUBSEP)
    print part[1], part[2], part[3], part[4], count[key]
  }
}

