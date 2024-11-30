// compile using gcc netlink_client.c main.c -o netlink_client -g
int userspace_netlink();

int main(int args, char *argv[])
{
	userspace_netlink();
	return 0;
}
