import os
from flask import Flask, render_template, request, redirect, url_for
from werkzeug.utils import secure_filename
from ultralytics import YOLO
import cv2
import numpy as np
from paddleocr import PaddleOCR
import re
from datetime import datetime

app = Flask(__name__)

UPLOAD_FOLDER = os.path.join(app.root_path, 'static', 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

MODEL_PATH = os.path.join(app.root_path, "models/expiry_date_reader_model.pt")
model = YOLO(MODEL_PATH)
print("Model loaded successfully")
ocr = PaddleOCR(use_angle_cls=True, lang='en')
print("OCR loaded successfully")

def standardize_date(text):
    months = {
        'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04', 'may': '05', 'jun': '06',
        'jul': '07', 'aug': '08', 'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12'
    }
    text = text.lower().strip()
    match = re.search(r'(\d{1,2})[\-/](\d{4})', text)
    if match:
        month, year = match.groups()
        return f"{year}-{int(month):02d}-01"
    match = re.search(r'(\d{4})[\-/](\d{1,2})', text)
    if match:
        year, month = match.groups()
        return f"{year}-{int(month):02d}-01"
    match = re.search(r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z\.\:]*(\d{4})', text)
    if match:
        month, year = match.groups()
        return f"{year}-{months[month[:3]]}-01"
    return None

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/expiry-date-reader", methods=["GET", "POST"])
def expiry_date_reader():
    uploaded_image = None
    result_image = None
    extracted_dates = []
    standardized_dates = []
    final_date = None

    if request.method == "POST":
        if "image" in request.files:
            image = request.files["image"]
            if image.filename != "":
                filename = secure_filename(image.filename)
                upload_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
                image.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
                uploaded_image = filename

                print("Image has been uploaded successfully")
                results = model(upload_path)
                print("Model has been executed successfully")
                print("Results:", results)
                result_filename = f"result_{filename}"
                result_path = os.path.join(app.config['UPLOAD_FOLDER'], result_filename)
                results[0].save(result_path)
                print("Result image has been saved successfully")
                result_image = result_filename
                
                boxes = results[0].boxes.xyxy.cpu().numpy() if hasattr(results[0].boxes, 'xyxy') else []
                img = cv2.imread(upload_path)
                print("Image has been read successfully")
                print("Boxes:", boxes)
                cropped_images = []
                for box in boxes:
                    x1, y1, x2, y2 = map(int, box)
                    crop = img[y1:y2, x1:x2]
                    if crop.size > 0:
                        cropped_images.append(crop)

                for crop in cropped_images:
                    crop_rgb = cv2.cvtColor(crop, cv2.COLOR_BGR2RGB)
                    ocr_result = ocr.ocr(crop_rgb, cls=True)
                    for line in ocr_result[0]:
                        text = line[1][0]
                        extracted_dates.append(text)
                        print("Extracted text:", text)
                        std_date = standardize_date(text)
                        print("Standardized date:", std_date)
                        if std_date:
                            standardized_dates.append(std_date)

                if standardized_dates:
                    try:
                        date_objs = [datetime.strptime(d, "%Y-%m-%d") for d in standardized_dates]
                        max_date = max(date_objs)
                        final_date = max_date.strftime("%Y-%m-%d")
                        print("Final date:", final_date)
                    except Exception:
                        final_date = standardized_dates[0]

    return render_template("expiry.html", uploaded_image=uploaded_image, result_image=result_image, extracted_dates=extracted_dates, standardized_dates=standardized_dates, final_date=final_date)

@app.route("/adherence-assistant", methods=["GET", "POST"])
def adherence_assistant():
    return render_template("adherence.html")

if __name__ == "__main__":
    app.run(debug=True)
