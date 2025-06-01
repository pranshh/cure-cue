import os
from flask import Flask, render_template, request, jsonify
from werkzeug.utils import secure_filename
from ultralytics import YOLO
import cv2
import numpy as np
from paddleocr import PaddleOCR
import re
from datetime import datetime
# import google.generativeai as genai

app = Flask(__name__)

# genai.configure(api_key="AIzaSyDChfe8INK6TpAJgFQ8gVKvSvf1Pgfiu6k")
# gemini = genai.GenerativeModel("gemini-2.0-flash")

# UPLOAD_FOLDER = os.path.join(app.root_path, 'static', 'uploads')
# os.makedirs(UPLOAD_FOLDER, exist_ok=True)
# app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

# MODEL_PATH = os.path.join(app.root_path, "models/expiry_date_reader_model.pt")
# model = YOLO(MODEL_PATH)
# print("Model loaded successfully")
# ocr = PaddleOCR(use_angle_cls=True, lang='en')
# print("OCR loaded successfully")

# def standardize_date(text):
#     months = {
#         'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04', 'may': '05', 'jun': '06',
#         'jul': '07', 'aug': '08', 'sep': '09', 'oct': '10', 'nov': '11', 'dec': '12'
#     }
#     text = text.lower().strip()
#     match = re.search(r'(\d{1,2})[\-/](\d{4})', text)
#     if match:
#         month, year = match.groups()
#         return f"{year}-{int(month):02d}-01"
#     match = re.search(r'(\d{4})[\-/](\d{1,2})', text)
#     if match:
#         year, month = match.groups()
#         return f"{year}-{int(month):02d}-01"
#     match = re.search(r'(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)[a-z\.\:]*(\d{4})', text)
#     if match:
#         month, year = match.groups()
#         return f"{year}-{months[month[:3]]}-01"
#     return None

# def get_today_date():
#     # Returns today's date in YYYY-MM-DD format
#     return datetime.now().date().isoformat()

@app.route("/")
def index():
    return render_template("landing_page.html")

# @app.route("/expiry-date-reader", methods=["GET", "POST"])
# def expiry_date_reader():
#     uploaded_image = None
#     result_image = None
#     extracted_dates = []
#     standardized_dates = []
#     final_date = None

#     if request.method == "POST":
#         if "image" in request.files:
#             image = request.files["image"]
#             if image.filename != "":
#                 filename = secure_filename(image.filename)
#                 upload_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
#                 image.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
#                 uploaded_image = filename

#                 print("Image has been uploaded successfully")
#                 results = model(upload_path)
#                 print("Model has been executed successfully")
#                 print("Results:", results)
#                 result_filename = f"result_{filename}"
#                 result_path = os.path.join(app.config['UPLOAD_FOLDER'], result_filename)
#                 results[0].save(result_path)
#                 print("Result image has been saved successfully")
#                 result_image = result_filename
                
#                 boxes = results[0].boxes.xyxy.cpu().numpy() if hasattr(results[0].boxes, 'xyxy') else []
#                 img = cv2.imread(upload_path)
#                 print("Image has been read successfully")
#                 print("Boxes:", boxes)
#                 cropped_images = []
#                 for box in boxes:
#                     x1, y1, x2, y2 = map(int, box)
#                     crop = img[y1:y2, x1:x2]
#                     if crop.size > 0:
#                         cropped_images.append(crop)

#                 for crop in cropped_images:
#                     crop_rgb = cv2.cvtColor(crop, cv2.COLOR_BGR2RGB)
#                     ocr_result = ocr.ocr(crop_rgb, cls=True)
#                     for line in ocr_result[0]:
#                         text = line[1][0]
#                         extracted_dates.append(text)
#                         print("Extracted text:", text)
#                         std_date = standardize_date(text)
#                         print("Standardized date:", std_date)
#                         if std_date:
#                             standardized_dates.append(std_date)

#                 if standardized_dates:
#                     try:
#                         date_objs = [datetime.strptime(d, "%Y-%m-%d") for d in standardized_dates]
#                         max_date = max(date_objs)
#                         final_date = max_date.strftime("%Y-%m-%d")
#                         print("Final date:", final_date)
#                     except Exception:
#                         final_date = standardized_dates[0]

#     return render_template("expiry.html", uploaded_image=uploaded_image, result_image=result_image, extracted_dates=extracted_dates, standardized_dates=standardized_dates, final_date=final_date)

# @app.route("/adherence-assistant", methods=["GET", "POST"])
# def adherence_assistant():
#     return render_template("adherence.html")

# @app.route('/extract_medication', methods=['POST'])
# def extract_medication():
#     if 'audio' not in request.files:
#         return jsonify({'error': 'No audio file provided'}), 400

#     audio_file = request.files['audio']
#     audio_content = audio_file.read()

#     prompt = f"""
# You are a medical assistant. Extract the following information from the patient's speech:
# - medicine_name
# - dates (list the next dates based on the instruction and today's date: {get_today_date()})
# - frequency_in_a_day
# - time(s)

# Return the result as JSON like:
# {{
#   "medicine_name": "...",
#   "dates": ["DD-MM-YYYY", ...],
#   "frequency_in_a_day": ...,
#   "time(s)": ["..."]
# }}

# Patient speech:
# """

#     response = gemini.generate_content(
#         [prompt, audio_content],
#         generation_config={
#             "temperature": 0.2,
#             "top_p": 1,
#             "top_k": 32
#         }
#     )

#     try:
#         import json
#         result = json.loads(response.text)
#     except Exception as e:
#         return jsonify({'error': 'Failed to parse Gemini response', 'details': str(e), 'raw_response': response.text}), 500

#     return jsonify(result)

# @app.route('/extract_medicine_image', methods=['POST'])
# def extract_medicine_image():
#     if 'image' not in request.files:
#         return jsonify({'error': 'No image provided'}), 400

#     image_file = request.files['image']
#     if image_file.filename == "":
#         return jsonify({'error': 'Empty filename'}), 400

#     import numpy as np
#     file_bytes = np.frombuffer(image_file.read(), np.uint8)
#     img = cv2.imdecode(file_bytes, cv2.IMREAD_COLOR)
#     if img is None:
#         return jsonify({'error': 'Invalid image format'}), 400

#     try:
#         ocr_result = ocr.ocr(img, cls=True)
#     except Exception as e:
#         return jsonify({'error': 'OCR failed', 'details': str(e)}), 500

#     extracted_texts = []
#     for region in ocr_result:
#         for line in region:
#             extracted_texts.append(line[1][0])
#     all_text = " ".join(extracted_texts)

#     prompt = f"""
# You are a medical assistant. Given the OCR text extracted from an image of a medicine package:
# "{all_text}"
# Determine the medicine name present in the image and return the result as JSON in the following format:
# {{
#   "medicine_name": "..."
# }}
# """
#     response = gemini.generate_content(
#         [prompt],
#         generation_config={
#             "temperature": 0.2,
#             "top_p": 1,
#             "top_k": 32
#         }
#     )
#     try:
#         import json
#         result = json.loads(response.text)
#     except Exception as e:
#         return jsonify({
#             'error': 'Failed to parse Gemini response',
#             'details': str(e),
#             'raw_response': response.text
#         }), 500

#     return jsonify(result)

if __name__ == "__main__":
    app.run(debug=True)
