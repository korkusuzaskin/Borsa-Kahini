import os
import numpy as np
import pandas as pd
import yfinance as yf
from datetime import datetime
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware  # <--- YENİ EKLENDİ
from pydantic import BaseModel
from sklearn.preprocessing import MinMaxScaler
from tensorflow.keras.models import Sequential, load_model
from tensorflow.keras.layers import LSTM, Dense, Dropout

app = FastAPI()

# --- CORS AYARLARI (YENİ EKLENDİ) ---
# Bu kısım, iPhone/Web uygulamasının sunucuyla konuşmasına izin verir.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Tüm sitelerden gelen isteklere izin ver
    allow_credentials=True,
    allow_methods=["*"],  # GET, POST, OPTIONS hepsine izin ver
    allow_headers=["*"],
)
# ------------------------------------

# --- AYARLAR ---
start_date = "2015-01-01"
end_date = datetime.now().strftime('%Y-%m-%d')
time_step = 60
ESIK_DEGERI = 0.005


class HisseIstegi(BaseModel):
    sembol: str


def analiz_et(ticker):
    # Yahoo Finance kripto düzeltmesi (BTC.USD -> BTC-USD)
    if "." in ticker and "USD" in ticker:
        ticker = ticker.replace(".", "-")

    try:
        # 1. Veri İndirme
        df = yf.download(ticker, start=start_date, end=end_date, progress=False)
        if len(df) < 200:
            return None

        # 2. İndikatörler
        df['MA50'] = df['Close'].rolling(window=50).mean()
        df.dropna(inplace=True)

        # 3. Hazırlık
        data = df[['Close', 'MA50']].values
        scaler = MinMaxScaler(feature_range=(0, 1))
        scaled_data = scaler.fit_transform(data)

        scaler_target = MinMaxScaler(feature_range=(0, 1))
        scaler_target.fit(df[['Close']])

        x_input, y_output = [], []
        for i in range(time_step, len(scaled_data)):
            x_input.append(scaled_data[i - time_step:i, :])
            y_output.append(scaled_data[i, 0])

        x_input, y_output = np.array(x_input), np.array(y_output)
        x_input = np.reshape(x_input, (x_input.shape[0], x_input.shape[1], x_input.shape[2]))

        # 4. Model (Varsa Yükle, Yoksa Eğit)
        model_name = f"{ticker}_model.keras"
        if os.path.exists(model_name):
            model = load_model(model_name)
        else:
            model = Sequential()
            model.add(LSTM(50, return_sequences=True, input_shape=(x_input.shape[1], x_input.shape[2])))
            model.add(Dropout(0.2))
            model.add(LSTM(50))
            model.add(Dropout(0.2))
            model.add(Dense(1))
            model.compile(optimizer='adam', loss='mse')
            model.fit(x_input, y_output, epochs=10, batch_size=32, verbose=0)
            model.save(model_name)

        # 5. Tahmin
        last_block = scaled_data[-time_step:, :]
        x_future = np.reshape(last_block, (1, time_step, scaled_data.shape[1]))
        pred_scaled = model.predict(x_future, verbose=0)

        tahmin_numpy = scaler_target.inverse_transform(pred_scaled)[0, 0]
        tahmin = float(tahmin_numpy)

        fiyat_numpy = df['Close'].values.flatten()[-1]
        fiyat = float(fiyat_numpy)

        # Sinyal
        if tahmin > fiyat * (1 + ESIK_DEGERI):
            sinyal = "AL 🟢"
        elif tahmin < fiyat:
            sinyal = "SAT 🔴"
        else:
            sinyal = "BEKLE ⚪"

        return {
            "hisse": ticker,
            "fiyat": round(fiyat, 2),
            "tahmin": round(tahmin, 2),
            "fark": round(((tahmin - fiyat) / fiyat) * 100, 2),
            "sinyal": sinyal
        }
    except Exception as e:
        print(f"Hata: {e}")
        return None


@app.post("/analiz")
def api_analiz(istek: HisseIstegi):
    sonuc = analiz_et(istek.sembol)
    if sonuc:
        return sonuc
    raise HTTPException(status_code=404, detail="Analiz başarısız")


@app.get("/")
def ana_sayfa():
    return {"mesaj": "Yapay Zeka Sunucusu Aktif ve Çalışıyor! 🚀"}
