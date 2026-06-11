docker system df
sudo docker stop $(sudo docker ps -aq)
sudo docker system prune -a --volumes -f
docker system df
