FROM belly/buildstep
ADD . /app
RUN /build/builder
CMD /start clock
