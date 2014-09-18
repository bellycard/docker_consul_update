FROM belly/buildstep

# Run build against Gemfile first so subsequent builds are much faster
ADD Gemfile /app/Gemfile
ADD Gemfile.lock /app/Gemfile.lock
RUN /build/builder

ADD . /app
CMD /start clock
