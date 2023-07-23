import os
import random
import numpy as np
import pandas as pd
import lightgbm as lgbm
import seaborn as sns
import csv

import matplotlib.pyplot as plt
from sklearn.model_selection import StratifiedKFold, GroupKFold
from sklearn.metrics import mean_squared_error
from glob import glob
from timer import Timer
from create_features import create_feature
from create_features import train_df, test_df, root_mean_squared_error

INPUT_DIR = "dataset"
OUTPUT_DIR = "outputs/tutorial-1"

os.makedirs(OUTPUT_DIR, exist_ok = True)

with Timer(prefix = "train..."):
    train_feat_df = create_feature(train_df)

with Timer(prefix = "test..."):
    test_feat_df = create_feature(test_df)

X = train_feat_df.values
y = train_df["score"].values

params = {
    # 目的関数. これの意味で最小となるようなパラメータを探します. 
    "objective": "rmse",

    # 木の最大数. early_stopping という枠組みで木の数は制御されるようにしていますのでとても大きい値を指定しておきます.
    "n_estimators": 10000,

    # 学習率. 小さいほどなめらかな決定境界が作られて性能向上に繋がる場合が多いです、
    # がそれだけ木を作るため学習に時間がかかります
    "learning_rate": .1,

    # 特徴重要度計算のロジック(後述)
    "importance_type": "gain",
    "random_state": 510,
    "early_stopping_rounds": 100,
}


def fit_lgbm(X,
             y,
             cv,
             params: dict = None,
             verbose: int = 50):
    """lightGBM を CrossValidation の枠組みで学習を行なう function"""

    # パラメータがないときは、空の dict で置き換える
    if params is None:
        params = {}

    models = []
    n_records = len(X)
    # training data の target と同じだけのゼロ配列を用意
    oof_pred = np.zeros((n_records,), dtype = np.float32)

    for i, (idx_train, idx_valid) in enumerate(cv):
        # この部分が交差検証のところです。データセットを cv instance によって分割します
        # training data を trian/valid に分割
        x_train, y_train = X[idx_train], y[idx_train]
        x_valid, y_valid = X[idx_valid], y[idx_valid]

        clf = lgbm.LGBMRegressor(**params)

        with Timer(prefix = "fit fold={} ".format(i)):
            # cv 内で train に定義された x_train で学習する
            clf.fit(x_train, y_train,
                    eval_set = [(x_valid, y_valid)])

        # cv 内で validation data とされた x_valid で予測をして oof_pred に保存していく
        # oof_pred は全部学習に使わなかったデータの予測結果になる → モデルの予測性能を見る指標として利用できる
        pred_i = clf.predict(x_valid)
        oof_pred[idx_valid] = pred_i
        models.append(clf)
        score = root_mean_squared_error(y_valid, pred_i)
        print(f" - fold{i + 1} - {score:.4f}")

    score = root_mean_squared_error(y, oof_pred)

    print("=" * 50)
    print(f"FINISHI: Whole Score: {score:.4f}")
    return oof_pred, models


fold = GroupKFold(n_splits = 5)
cv = fold.split(X, y, groups = train_df["user_id"])
cv = list(cv)

oof, models = fit_lgbm(X, y = y, params = params, cv = cv)


def visualize_importance(models, feat_train_df):
    """lightGBM の model 配列の feature importance を plot する
    CVごとのブレを boxen plot として表現します.

    args:
        models:
            List of lightGBM models
        feat_train_df:
            学習時に使った DataFrame
    """
    feature_importance_df = pd.DataFrame()
    for i, model in enumerate(models):
        _df = pd.DataFrame()
        _df["feature_importance"] = model.feature_importances_
        _df["column"] = feat_train_df.columns
        _df["fold"] = i + 1
        feature_importance_df = pd.concat([feature_importance_df, _df],
                                          axis = 0, ignore_index = True)

    order = feature_importance_df.groupby("column") \
                .sum()[["feature_importance"]] \
                .sort_values("feature_importance", ascending = False).index[:50]

    fig, ax = plt.subplots(figsize = (12, max(6, len(order) * .25)))
    sns.boxenplot(data = feature_importance_df,
                  x = "feature_importance",
                  y = "column",
                  order = order,
                  ax = ax,
                  palette = "viridis",
                  orient = "h")
    ax.tick_params(axis = "x", rotation = 90)
    ax.set_title("Importance")
    ax.grid()
    fig.tight_layout()
    return fig, ax


pred = np.array([model.predict(test_feat_df.values) for model in models])
pred = np.mean(pred, axis = 0)  # axis=0 なので shape の `k` が潰れる

pd.DataFrame({
    "score": pred
}).to_csv(os.path.join(OUTPUT_DIR, "submission_for_unseen.csv"), index = False)
