# Use an official Alpine Linux image as a parent image
FROM alpine:3.12

# Install dependencies
RUN apk --no-cache add curl jq bash

# Copy the entrypoint script into the container
COPY entrypoint.sh /entrypoint.sh

# Make the entrypoint script executable
RUN chmod +x /entrypoint.sh

# Set the entrypoint
ENTRYPOINT ["/entrypoint.sh"]
