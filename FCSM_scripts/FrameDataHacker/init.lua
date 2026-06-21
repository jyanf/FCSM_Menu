local relative = ... and (...):gsub("%.init$", "").."." or ""
return require(relative.."hacker")