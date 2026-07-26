FROM python:3.8-slim
RUN pip install flask OTXv2
COPY resources/otx-api.py /otx-api.py
CMD ["python", "/otx-api.py"]
