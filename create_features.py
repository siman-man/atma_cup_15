import os
import numpy as np
import pandas as pd
import lightgbm as lgbm
import seaborn as sns
import csv

import matplotlib.pyplot as plt
from sklearn.model_selection import StratifiedKFold
from sklearn.metrics import mean_squared_error
from sklearn.preprocessing import LabelEncoder
from glob import glob
from timer import Timer
from sklearn.metrics import mean_squared_error

INPUT_DIR = "dataset"


def get_genre_list(row):
    genre_list = list(map(lambda x: x.strip().lower(), row['genres'].split(',')))

    return genre_list


def get_all_genres(df):
    genre_list = []
    for idx, row in df.iterrows():
        genre_list.extend(get_genre_list(row))

    return list(set(genre_list))


def root_mean_squared_error(y_true, y_pred):
    """mean_squared_error の root (0.5乗)"""
    return mean_squared_error(y_true, y_pred) ** .5


def read_csv(name: str, **kwrgs) -> pd.DataFrame:
    p = os.path.join(INPUT_DIR, name + ".csv")
    return pd.read_csv(p, **kwrgs)


def merge_by_anime_id(left_df, right_df):
    return pd.merge(left_df["anime_id"], right_df, on = "anime_id", how = "left").drop(columns = ["anime_id"])


def merge_by_user_id(left_df, right_df):
    return pd.merge(left_df["user_id"], right_df, on = "user_id", how = "left").drop(columns = ["user_id"])


def create_anime_numeric_feature(input_df: pd.DataFrame):
    """input_dfは train or test.csv のデータが入ってくることを想定しています."""
    use_columns = [
        "main_producer",
        "main_studio",
        "members",
        "watching",
        "completed",
        "on_hold",
        "dropped",
        "plan_to_watch",
        "comp_rate",
        "hold_rate",
        "drop_rate",
    ]
    use_columns.extend(map(lambda x: "anime_" + str(x + 1) + "_review_count", range(10)))

    return merge_by_anime_id(input_df, anime_df)[use_columns]


def create_user_numeric_feature(input_df: pd.DataFrame):
    use_columns = [
        "watch_count",
    ]
    use_columns.extend(map(lambda x: x + "_rate", get_all_genres(anime_df)))

    return merge_by_user_id(input_df, user_df)[use_columns]


def create_anime_source_count_encoding(input_df):
    count = anime_df["source"].map(anime_df["source"].value_counts())
    encoded_df = pd.DataFrame({
        "anime_id": anime_df["anime_id"],
        "source_count": count
    })

    return merge_by_anime_id(input_df, encoded_df)


def create_anime_rating_count_encoding(input_df):
    count = anime_df["rating"].map(anime_df["rating"].value_counts())
    encoded_df = pd.DataFrame({
        "anime_id": anime_df["anime_id"],
        "rating_count": count
    })

    return merge_by_anime_id(input_df, encoded_df)


def create_anime_genre_one_hot_encoding(input_df):
    unique_values = get_all_genres(anime_df)

    out_df = pd.DataFrame()

    for value in unique_values:
        out_df[value] = anime_df[value]

    out_df["anime_id"] = anime_df["anime_id"]

    return merge_by_anime_id(input_df, out_df)


def create_anime_type_label_encoding(input_df):
    # 対象の列のユニーク集合を取る
    target_colname = "type"

    out_df = pd.DataFrame()
    le = LabelEncoder()
    le.fit(anime_df[target_colname])
    out_df[target_colname] = le.transform(anime_df[target_colname])
    out_df["anime_id"] = anime_df["anime_id"]

    return merge_by_anime_id(input_df, out_df)


def create_feature(input_df):
    # functions に特徴量作成関数を配列で定義しました.
    # どの関数も同じ input / output のインターフェイスなので for で回せて嬉しいですね ;)
    functions = [
        create_user_numeric_feature,
        create_anime_numeric_feature,
        create_anime_source_count_encoding,
        create_anime_rating_count_encoding,
        create_anime_type_label_encoding,
        create_anime_genre_one_hot_encoding,
    ]

    out_df = pd.DataFrame()
    for func in functions:
        func_name = str(func.__name__)
        with Timer(prefix = f"create {func_name}"):
            _df = func(input_df)
        out_df = pd.concat([out_df, _df], axis = 1)

    return out_df


anime_df = read_csv("anime_rebuild")
user_df = read_csv("users")
train_df = read_csv("train")
test_df = read_csv("test")

if __name__ == "__main__":
    test_feat_df = create_feature(test_df)
    print(test_feat_df.head())
