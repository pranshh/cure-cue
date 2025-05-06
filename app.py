import os
from flask import Flask, render_template, request, redirect, url_for
from werkzeug.utils import secure_filename

app = Flask(__name__)

UPLOAD_FOLDER = os.path.join(app.root_path, 'static', 'uploads')
os.makedirs(UPLOAD_FOLDER, exist_ok=True)
app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

@app.route("/")
def index():
    return render_template("index.html")

@app.route("/expiry-date-checker", methods=["GET", "POST"])
def expiry_date_checker():
    uploaded_image = None
    if request.method == "POST":
        if "image" in request.files:
            image = request.files["image"]
            if image.filename != "":
                filename = secure_filename(image.filename)
                image.save(os.path.join(app.config['UPLOAD_FOLDER'], filename))
                uploaded_image = filename
    return render_template("expiry.html", uploaded_image=uploaded_image)

if __name__ == "__main__":
    app.run(debug=True)
