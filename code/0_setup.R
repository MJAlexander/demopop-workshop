######## DemPop Workshop ############
######## Monica Alexander ##############
#########  0. Set-up ###################

# The purpose of this script is to make sure you have all the required packages installed and make sure everything is working
# that will allow you to follow along executing the code if you want
# We will extract some tweets and do some sentiment analysis
# Below is a list of packages you will need to have installed. 
# If you don't have them installed, you can install them using "install.packages()"
# For example to install tidyverse, run install.packages("tidyverse")

# If you want to follow along, you need a Twitter account! 
# This is required to authenticate your requests for Twitter data. 
# If you don’t already have an account, you can sign up here: https://twitter.com/.

# Load packages -----------------------------------------------------------

library(tidyverse)
library(here)
library(rtweet)
library(tidytext)
library(lubridate)
library(scales)
library(rvest)
library(topicmodels)



# Twitter test ------------------------------------------------------------

### Below are a few lines of code to test that you have rtweet working. 
### NOTE: You must have a Twitter account!
### All users must be authenticated to interact with Twitter’s APIs. 
### The easiest way to authenticate is to use your personal twitter account 
### This will happen automatically (via a browser popup) the first time you use an rtweet function.
### Once you authenticate, you shouldn't have to do it again

# get Twitter info for monica's account.
# The monica_info object should be a tibble with dimensions 1 x 90
monica_info <- lookup_users("monjalexander") 

# extract location info
monica_info$location # should return "Toronto, Ontario"

# get most recent 1200 tweets
# The monica_timeline object should be a tibble of dimensions 1200 x 90
monica_timeline <- get_timeline("monjalexander", n = 1200)

# Tidytext test -----------------------------------------------------------

tidy_tweets <- monica_timeline %>% 
  mutate(tweet = row_number()) %>% 
  filter(is_retweet==FALSE) %>% 
  mutate(text = str_trim(str_replace_all(text, "@[A-Za-z0-9]+\\w+", ""))) %>% # remove twitter handles
  select(created_at, tweet, text) %>% 
  unnest_tokens(word, text)

tidy_tweets %>% 
  count(word, sort = TRUE) 

bing <- get_sentiments("bing")

# calculate the proportion of positive words in tweets by month
prop_positive <- tidy_tweets %>% 
  # the next three lines convert created_at just to month_year
  separate(created_at, into = c("date", "time"), sep = " ") %>% 
  separate(date, into = c("year", "month", "day"), sep = "-") %>% 
  mutate(month_year = my(paste(month, year))) %>% 
  select(month_year, tweet, word) %>% 
  inner_join(bing) %>% 
  group_by(month_year, sentiment) %>% 
  tally() %>% 
  group_by(month_year) %>% 
  summarise(prop_positive = n[sentiment == "positive"]/sum(n))

# plot! this should be a plot over time starting in about March 2021
ggplot(prop_positive, aes(month_year, prop_positive)) +
  geom_point(color = "darkblue", size = 3) + geom_line(color = "darkblue", lwd = 1.2)  +
  labs(title = "Positive words used in Monica's tweets", 
       subtitle = "Proportion of total words",
       x = "", y = "proportion") + 
  scale_x_date(labels = date_format("%m-%Y"))+ 
  theme_bw(base_size = 14)


# LDA test ----------------------------------------------------------------

tweet_dtm <- tidy_tweets %>% 
  anti_join(stop_words) %>% 
  filter(word!="https", word!="t.co") %>% 
  filter(is.na(as.numeric(word))) %>% 
  group_by(tweet, word) %>% 
  tally() %>% 
  cast_dtm(tweet, word, n)

tweet_lda <- LDA(tweet_dtm, k = 3, control = list(seed= 83))

tidy(tweet_lda, matrix = "beta") %>% 
  group_by(topic) %>%
  slice_max(beta, n = 10) %>% 
  ungroup() %>%
  arrange(topic, -beta) %>% 
  mutate(term = reorder_within(term, beta, topic)) %>%
  ggplot(aes(beta, term, fill = factor(topic))) +
  geom_col(show.legend = FALSE) +
  facet_wrap(~ topic, scales = "free") +
  scale_y_reordered()+
  labs(title = "Topics of Monica's tweets", x = "probability of word in topic")




