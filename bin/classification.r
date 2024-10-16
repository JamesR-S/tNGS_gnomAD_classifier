library(randomForest)


args <- commandArgs(trailingOnly = TRUE)

mydata <- read.table(args[1], header=TRUE, sep="\t");
rows_with_na <- apply(mydata, MARGIN = 1, FUN = function(x) any(is.na(x)))
print(paste0(sum(rows_with_na)," individuals with no PC data. IDs saved to unprocessed_ids.txt")) 
write.table(mydata$indivID[rows_with_na],"unprocessed_ids.txt",quote = FALSE, sep = "\t", row.names = FALSE, col.names = FALSE)
mydata <- mydata[!rows_with_na,]

args_all <- commandArgs(trailingOnly = FALSE)
script_path <- normalizePath(sub("^--file=", "", args_all[grep("--file=", args_all)]))
script_dir <- dirname(script_path)
model_path <- file.path(script_dir, "../resources/classification_model.RData")
load(model_path)

predictions <- predict(final_model, newdata=mydata)
predicted_probs <- predict(final_model, newdata = mydata, type = "prob")
predicted_probs_max <- apply(predicted_probs, 1, max, na.rm = TRUE)
predicted_probs <- as.data.frame(predicted_probs)
predictions <- factor(predictions, levels = c("afr","amr","eas","fin","mid","nfe","sas","oth"))
predictions[predicted_probs_max<args[2]] <- "oth"

predicted_probs$prediction <- predictions

predicted_probs$id <- mydata$indivID

predicted_probs <- predicted_probs[,c(9,1:7,8)]

write.table(predicted_probs,args[3],quote = FALSE, sep = "\t", row.names = FALSE, col.names = TRUE)

